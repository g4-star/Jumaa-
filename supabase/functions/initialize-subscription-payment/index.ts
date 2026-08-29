import { corsHeaders } from '../_shared/cors.ts';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const PAYSTACK_SECRET_KEY = Deno.env.get('PAYSTACK_SECRET_KEY');
function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json'
    }
  });
}
Deno.serve(async (req)=>{
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders
    });
  }
  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY || !PAYSTACK_SECRET_KEY) {
      throw new Error('Required Supabase or Paystack secrets are not configured.');
    }
    const body = await req.json();
    if (!body.owner_id || !body.property_id || !body.amount || !body.email) {
      return jsonResponse({
        success: false,
        error: 'owner_id, property_id, amount and email are required.'
      }, 400);
    }
    if (body.amount <= 0) {
      return jsonResponse({
        success: false,
        error: 'Payment amount must be greater than zero.'
      }, 400);
    }
    // ----------------------------------------------------------
    // 1. Load the owner's subscription.
    // ----------------------------------------------------------
    const subscriptionResponse = await fetch(`${SUPABASE_URL}/rest/v1/subscriptions?owner_id=eq.${encodeURIComponent(body.owner_id)}&property_id=eq.${encodeURIComponent(body.property_id)}&select=*`, {
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
      }
    });
    if (!subscriptionResponse.ok) {
      throw new Error('Could not load the property subscription.');
    }
    const subscriptions = await subscriptionResponse.json();
    if (!Array.isArray(subscriptions) || subscriptions.length === 0) {
      return jsonResponse({
        success: false,
        error: 'No subscription exists for this property.'
      }, 404);
    }
    const subscription = subscriptions[0];
    const monthlyAmount = Number(subscription.monthly_amount) || 0;
    if (monthlyAmount <= 0) {
      return jsonResponse({
        success: false,
        error: 'The subscription does not have a valid monthly amount.'
      }, 400);
    }
    // ----------------------------------------------------------
    // 2. Prevent underpayment.
    // ----------------------------------------------------------
    if (body.amount < monthlyAmount) {
      return jsonResponse({
        success: false,
        error: `Minimum payment is KES ${monthlyAmount.toFixed(2)}.`,
        minimum_amount: monthlyAmount
      }, 400);
    }
    // ----------------------------------------------------------
    // 3. Generate our own unique reference.
    // ----------------------------------------------------------
    const reference = `JUMAA-${crypto.randomUUID().replaceAll('-', '')}`;
    // Paystack expects amount in the currency subunit.
    const paystackAmount = Math.round(body.amount * 100);
    // ----------------------------------------------------------
    // 4. Initialize Paystack transaction.
    // ----------------------------------------------------------
    const paystackResponse = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        email: body.email,
        amount: paystackAmount,
        currency: 'KES',
        reference,
        channels: [
          'mobile_money',
          'card',
          'bank'
        ],
        metadata: {
          owner_id: body.owner_id,
          property_id: body.property_id,
          subscription_id: subscription.id,
          amount: body.amount,
          monthly_amount: monthlyAmount
        }
      })
    });
    const paystackResult = await paystackResponse.json();
    if (!paystackResponse.ok || !paystackResult.status) {
      console.error('Paystack initialization error:', paystackResult);
      return jsonResponse({
        success: false,
        error: paystackResult?.message ?? 'Could not initialize Paystack payment.'
      }, 400);
    }
    // ----------------------------------------------------------
    // 5. Create pending subscription payment record.
    // ----------------------------------------------------------
    const paymentInsertResponse = await fetch(`${SUPABASE_URL}/rest/v1/subscription_payments`, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        'Content-Type': 'application/json',
        Prefer: 'return=representation'
      },
      body: JSON.stringify({
        owner_id: body.owner_id,
        property_id: body.property_id,
        subscription_id: subscription.id,
        amount: body.amount,
        monthly_rate: monthlyAmount,
        units_count: subscription.unit_count,
        months_covered: 0,
        credit_generated: 0,
        payment_method: 'paystack',
        reference,
        status: 'pending'
      })
    });
    if (!paymentInsertResponse.ok) {
      const errorText = await paymentInsertResponse.text();
      console.error('Subscription payment insert error:', errorText);
      throw new Error('Could not create the pending payment record.');
    }
    return jsonResponse({
      success: true,
      reference,
      authorization_url: paystackResult.data.authorization_url,
      access_code: paystackResult.data.access_code,
      subscription_id: subscription.id,
      amount: body.amount,
      monthly_amount: monthlyAmount
    });
  } catch (error) {
    console.error(error);
    return jsonResponse({
      success: false,
      error: error instanceof Error ? error.message : String(error)
    }, 500);
  }
});
