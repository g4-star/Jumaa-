import { createHmac } from "node:crypto";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
const PAYSTACK_SECRET_KEY = Deno.env.get("PAYSTACK_SECRET_KEY");
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-paystack-signature",
  "Access-Control-Allow-Methods": "POST, OPTIONS"
};
function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json"
    }
  });
}
async function supabaseFetch(path, options = {}) {
  return fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...options,
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
      ...options.headers ?? {}
    }
  });
}
Deno.serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  if (req.method !== "POST") {
    return jsonResponse({
      success: false,
      error: "Method not allowed."
    }, 405);
  }
  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !PAYSTACK_SECRET_KEY) {
      throw new Error("Required Supabase or Paystack secrets are not configured.");
    }
    // ----------------------------------------------------------
    // 1. Read the raw request body.
    // ----------------------------------------------------------
    const rawBody = await req.text();
    // ----------------------------------------------------------
    // 2. Verify Paystack webhook signature.
    // ----------------------------------------------------------
    const signature = req.headers.get("x-paystack-signature");
    if (!signature) {
      return jsonResponse({
        success: false,
        error: "Missing Paystack signature."
      }, 401);
    }
    const expectedSignature = createHmac("sha512", PAYSTACK_SECRET_KEY).update(rawBody).digest("hex");
    if (signature !== expectedSignature) {
      console.error("Invalid Paystack webhook signature.");
      return jsonResponse({
        success: false,
        error: "Invalid Paystack signature."
      }, 401);
    }
    const event = JSON.parse(rawBody);
    console.log("PAYSTACK WEBHOOK EVENT:", event?.event);
    // ----------------------------------------------------------
    // 3. We only activate subscriptions after charge.success.
    // ----------------------------------------------------------
    if (event?.event !== "charge.success") {
      return jsonResponse({
        success: true,
        received: true,
        processed: false,
        event: event?.event ?? null
      });
    }
    const transaction = event?.data;
    if (!transaction?.reference) {
      throw new Error("Paystack transaction reference is missing.");
    }
    const reference = String(transaction.reference);
    // ----------------------------------------------------------
    // 4. Verify the transaction directly with Paystack.
    // ----------------------------------------------------------
    const verifyResponse = await fetch(`https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`
      }
    });
    const verifyResult = await verifyResponse.json();
    if (!verifyResponse.ok || !verifyResult?.status || verifyResult?.data?.status !== "success") {
      throw new Error("Paystack transaction verification failed.");
    }
    const verified = verifyResult.data;
    // ----------------------------------------------------------
    // 5. Find our payment record.
    // ----------------------------------------------------------
    const paymentResponse = await supabaseFetch(`subscription_payments?reference=eq.${encodeURIComponent(reference)}&select=*`);
    if (!paymentResponse.ok) {
      throw new Error(`Could not load subscription payment: ${await paymentResponse.text()}`);
    }
    const payments = await paymentResponse.json();
    if (!Array.isArray(payments) || payments.length === 0) {
      console.error("Payment reference not found:", reference);
      // Acknowledge the webhook so Paystack doesn't
      // repeatedly retry an unknown reference.
      return jsonResponse({
        success: true,
        received: true,
        processed: false,
        reason: "payment_not_found",
        reference
      });
    }
    const payment = payments[0];
    // ----------------------------------------------------------
    // 6. Idempotency.
    //
    // Paystack may send the same webhook more than once.
    // Never extend a subscription twice.
    // ----------------------------------------------------------
    if (payment.status === "success") {
      return jsonResponse({
        success: true,
        received: true,
        processed: false,
        reason: "already_processed",
        reference
      });
    }
    // ----------------------------------------------------------
    // 7. Confirm the Paystack amount.
    //
    // Our database stores KES.
    // Paystack returns the smallest currency unit.
    // Therefore:
    //
    //     database amount * 100 = Paystack amount
    // ----------------------------------------------------------
    const expectedAmount = Math.round(Number(payment.amount) * 100);
    const receivedAmount = Number(verified.amount);
    if (expectedAmount !== receivedAmount) {
      console.error("PAYMENT AMOUNT MISMATCH", {
        reference,
        expectedAmount,
        receivedAmount
      });
      throw new Error(`Payment amount mismatch. Expected ${expectedAmount}, received ${receivedAmount}.`);
    }
    // ----------------------------------------------------------
    // 8. Confirm currency.
    // ----------------------------------------------------------
    if (verified.currency && String(verified.currency).toUpperCase() !== "KES") {
      throw new Error(`Unexpected payment currency: ${verified.currency}`);
    }
    // ----------------------------------------------------------
    // 9. Load the subscription.
    // ----------------------------------------------------------
    if (!payment.subscription_id) {
      throw new Error("Payment does not have a subscription_id.");
    }
    const subscriptionResponse = await supabaseFetch(`subscriptions?id=eq.${encodeURIComponent(payment.subscription_id)}&select=*`);
    if (!subscriptionResponse.ok) {
      throw new Error(`Could not load subscription: ${await subscriptionResponse.text()}`);
    }
    const subscriptions = await subscriptionResponse.json();
    if (!Array.isArray(subscriptions) || subscriptions.length === 0) {
      throw new Error("Subscription associated with payment was not found.");
    }
    const subscription = subscriptions[0];
    // ----------------------------------------------------------
    // 10. Calculate months covered.
    //
    // Uses the database function created specifically for
    // JUMAA billing.
    // ----------------------------------------------------------
    const monthsResponse = await fetch(`${SUPABASE_URL}/rest/v1/rpc/get_jumaa_months_covered`, {
      method: "POST",
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        p_amount: Number(payment.amount),
        p_monthly_rate: Number(payment.monthly_rate)
      })
    });
    if (!monthsResponse.ok) {
      throw new Error(`Could not calculate subscription months: ${await monthsResponse.text()}`);
    }
    const monthsCovered = Number(await monthsResponse.json());
    if (!Number.isInteger(monthsCovered) || monthsCovered <= 0) {
      throw new Error("Payment does not represent a valid whole number of subscription months.");
    }
    // ----------------------------------------------------------
    // 11. Calculate subscription dates.
    //
    // If there is an existing active subscription that has not
    // expired, extend from its current end date.
    //
    // Otherwise start from today.
    // ----------------------------------------------------------
    const now = new Date();
    let subscriptionStart;
    let subscriptionEndBase;
    const existingEnd = subscription.subscription_ends_at ? new Date(subscription.subscription_ends_at) : null;
    const existingStart = subscription.subscription_starts_at ? new Date(subscription.subscription_starts_at) : null;
    if (existingEnd && !Number.isNaN(existingEnd.getTime()) && existingEnd > now && subscription.status === "active") {
      // Renewal while still active:
      // preserve the existing expiry date.
      subscriptionStart = existingStart && existingStart < now ? existingStart : now;
      subscriptionEndBase = existingEnd;
    } else {
      // New activation / expired / trial conversion.
      subscriptionStart = now;
      subscriptionEndBase = now;
    }
    const subscriptionEnd = new Date(subscriptionEndBase);
    subscriptionEnd.setUTCMonth(subscriptionEnd.getUTCMonth() + monthsCovered);
    // ----------------------------------------------------------
    // 12. Credit generated.
    //
    // The payment amount becomes the subscription credit
    // generated by this successful payment.
    // ----------------------------------------------------------
    const creditGenerated = Number(payment.amount);
    // ----------------------------------------------------------
    // 13. Update payment record.
    // ----------------------------------------------------------
    const paymentUpdateResponse = await supabaseFetch(`subscription_payments?id=eq.${encodeURIComponent(payment.id)}`, {
      method: "PATCH",
      headers: {
        Prefer: "return=minimal"
      },
      body: JSON.stringify({
        status: "success",
        months_covered: monthsCovered,
        credit_generated: creditGenerated,
        paid_at: new Date().toISOString()
      })
    });
    if (!paymentUpdateResponse.ok) {
      throw new Error(`Could not update subscription payment: ${await paymentUpdateResponse.text()}`);
    }
    // ----------------------------------------------------------
    // 14. Update the subscription.
    //
    // A successful payment:
    //   - activates the subscription
    //   - records its start date
    //   - extends its end date
    //   - adds the generated credit
    // ----------------------------------------------------------
    const currentCredit = Number(subscription.credit_amount) || 0;
    const newCredit = currentCredit + creditGenerated;
    const subscriptionUpdateResponse = await supabaseFetch(`subscriptions?id=eq.${encodeURIComponent(subscription.id)}`, {
      method: "PATCH",
      headers: {
        Prefer: "return=minimal"
      },
      body: JSON.stringify({
        status: "active",
        subscription_starts_at: subscriptionStart.toISOString(),
        subscription_ends_at: subscriptionEnd.toISOString(),
        credit_amount: newCredit,
        updated_at: new Date().toISOString()
      })
    });
    if (!subscriptionUpdateResponse.ok) {
      throw new Error(`Could not activate subscription: ${await subscriptionUpdateResponse.text()}`);
    }
    console.log("SUBSCRIPTION ACTIVATED:", {
      reference,
      subscription_id: subscription.id,
      owner_id: payment.owner_id,
      property_id: payment.property_id,
      amount: payment.amount,
      months_covered: monthsCovered,
      credit_generated: creditGenerated,
      subscription_starts_at: subscriptionStart.toISOString(),
      subscription_ends_at: subscriptionEnd.toISOString()
    });
    return jsonResponse({
      success: true,
      received: true,
      processed: true,
      reference,
      payment_id: payment.id,
      subscription_id: subscription.id,
      months_covered: monthsCovered,
      credit_generated: creditGenerated,
      subscription_starts_at: subscriptionStart.toISOString(),
      subscription_ends_at: subscriptionEnd.toISOString()
    });
  } catch (error) {
    console.error("PAYSTACK WEBHOOK ERROR:", error);
    return jsonResponse({
      success: false,
      error: error instanceof Error ? error.message : String(error)
    }, 500);
  }
});
