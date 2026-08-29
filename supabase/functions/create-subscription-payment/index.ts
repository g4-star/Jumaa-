import { corsHeaders } from '../_shared/cors.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const PAYSTACK_SECRET_KEY = Deno.env.get('PAYSTACK_SECRET_KEY')!;

interface PaymentRequest {
  owner_id: string;
  property_id: string;
  amount: number;
  phone: string;
}

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function normalizeKenyanPhone(phone: string): string {
  const value = phone.trim().replace(/\s+/g, '');

  if (value.startsWith('+254')) {
    return value;
  }

  if (value.startsWith('254')) {
    return `+${value}`;
  }

  if (value.startsWith('0') && value.length === 10) {
    return `+254${value.substring(1)}`;
  }

  return value;
}

async function supabaseFetch(
  path: string,
  options: RequestInit = {},
) {
  return fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...options,
    headers: {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      ...(options.headers ?? {}),
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders,
    });
  }

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      return jsonResponse(
        {
          success: false,
          error: 'Supabase service credentials are not configured.',
        },
        500,
      );
    }

    if (!PAYSTACK_SECRET_KEY) {
      return jsonResponse(
        {
          success: false,
          error: 'PAYSTACK_SECRET_KEY is not configured.',
        },
        500,
      );
    }

    const body: PaymentRequest = await req.json();

    if (
      !body.owner_id ||
      !body.property_id ||
      !body.amount ||
      !body.phone
    ) {
      return jsonResponse(
        {
          success: false,
          error:
            'owner_id, property_id, amount and phone are required.',
        },
        400,
      );
    }

    const requestedAmount = Number(body.amount);

    if (
      !Number.isFinite(requestedAmount) ||
      requestedAmount <= 0
    ) {
      return jsonResponse(
        {
          success: false,
          error: 'Invalid payment amount.',
        },
        400,
      );
    }

    // ----------------------------------------------------------
    // 1. Load the property
    // ----------------------------------------------------------

    const propertyResponse = await supabaseFetch(
      `properties?id=eq.${encodeURIComponent(
        body.property_id,
      )}&owner_id=eq.${encodeURIComponent(
        body.owner_id,
      )}&select=id,name,owner_id,email,phone`,
    );

    if (!propertyResponse.ok) {
      throw new Error('Could not load the property.');
    }

    const properties = await propertyResponse.json();

    if (!Array.isArray(properties) || properties.length === 0) {
      return jsonResponse(
        {
          success: false,
          error:
            'Property not found or does not belong to this owner.',
        },
        404,
      );
    }

    const property = properties[0];

    // ----------------------------------------------------------
    // 2. Count units directly from the database
    // ----------------------------------------------------------

    const unitsResponse = await supabaseFetch(
      `units?property_id=eq.${encodeURIComponent(
        body.property_id,
      )}&select=id`,
    );

    if (!unitsResponse.ok) {
      throw new Error('Could not count property units.');
    }

    const units = await unitsResponse.json();
    const unitCount = Array.isArray(units) ? units.length : 0;

    if (unitCount <= 0) {
      return jsonResponse(
        {
          success: false,
          error: 'This property has no units.',
        },
        400,
      );
    }

    // ----------------------------------------------------------
    // 3. Ask PostgreSQL for the official JUMAA monthly rate
    // ----------------------------------------------------------

    const rateResponse = await supabaseFetch(
      'rpc/get_jumaa_monthly_rate',
      {
        method: 'POST',
        body: JSON.stringify({
          p_unit_count: unitCount,
        }),
      },
    );

    if (!rateResponse.ok) {
      throw new Error(
        `Could not calculate JUMAA billing rate: ${await rateResponse.text()}`,
      );
    }

    const monthlyRate = Number(await rateResponse.json());

    if (!monthlyRate || monthlyRate <= 0) {
      return jsonResponse(
        {
          success: false,
          error:
            'This property requires a custom JUMAA subscription plan.',
          unit_count: unitCount,
        },
        400,
      );
    }

    // ----------------------------------------------------------
    // 4. Calculate months covered
    // ----------------------------------------------------------

    const monthsResponse = await supabaseFetch(
      'rpc/get_jumaa_months_covered',
      {
        method: 'POST',
        body: JSON.stringify({
          p_amount: requestedAmount,
          p_monthly_rate: monthlyRate,
        }),
      },
    );

    if (!monthsResponse.ok) {
      throw new Error(
        `Could not calculate subscription months: ${await monthsResponse.text()}`,
      );
    }

    const monthsCovered = Number(await monthsResponse.json());

    if (!Number.isInteger(monthsCovered) || monthsCovered <= 0) {
      return jsonResponse(
        {
          success: false,
          error:
            `Payment must be a whole number of months. ` +
            `Monthly JUMAA fee is KSh ${monthlyRate.toLocaleString()}.`,
          unit_count: unitCount,
          monthly_rate: monthlyRate,
          minimum_amount: monthlyRate,
        },
        400,
      );
    }

    // ----------------------------------------------------------
    // 5. Get/create the owner's subscription
    // ----------------------------------------------------------

    const subscriptionResponse = await supabaseFetch(
      `subscriptions?owner_id=eq.${encodeURIComponent(
        body.owner_id,
      )}&property_id=eq.${encodeURIComponent(
        body.property_id,
      )}&select=*`,
    );

    if (!subscriptionResponse.ok) {
      throw new Error('Could not load the subscription.');
    }

    const subscriptions = await subscriptionResponse.json();

    if (
      !Array.isArray(subscriptions) ||
      subscriptions.length === 0
    ) {
      return jsonResponse(
        {
          success: false,
          error:
            'No JUMAA subscription exists for this property.',
        },
        404,
      );
    }

    const subscription = subscriptions[0];

    // ----------------------------------------------------------
    // 6. Generate our own unique payment reference
    // ----------------------------------------------------------

    const reference =
      `JUMAA-${crypto.randomUUID().replaceAll('-', '').substring(0, 20)}`;

    // ----------------------------------------------------------
    // 7. Create pending payment record
    // ----------------------------------------------------------

    const paymentInsertResponse = await supabaseFetch(
      'subscription_payments',
      {
        method: 'POST',
        headers: {
          Prefer: 'return=representation',
        },
        body: JSON.stringify({
          owner_id: body.owner_id,
          property_id: body.property_id,
          subscription_id: subscription.id,
          amount: requestedAmount,
          monthly_rate: monthlyRate,
          units_count: unitCount,
          months_covered: monthsCovered,
          credit_generated: 0,
          payment_method: 'mpesa',
          reference,
          status: 'pending',
        }),
      },
    );

    if (!paymentInsertResponse.ok) {
      throw new Error(
        `Could not create payment record: ${await paymentInsertResponse.text()}`,
      );
    }

    // ----------------------------------------------------------
    // 8. Send M-PESA STK request to Paystack
    // ----------------------------------------------------------

    const customerEmail =
      property.email?.trim() ||
      `owner-${body.owner_id}@jumaa.app`;

    const customerPhone = normalizeKenyanPhone(body.phone);

    const paystackResponse = await fetch(
      'https://api.paystack.co/charge',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${PAYSTACK_SECRET_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email: customerEmail,
          amount: Math.round(requestedAmount * 100),
          currency: 'KES',
          reference,
          mobile_money: {
            phone: customerPhone,
            provider: 'mpesa',
          },
          metadata: {
            owner_id: body.owner_id,
            property_id: body.property_id,
            property_name: property.name,
            units_count: unitCount,
            monthly_rate: monthlyRate,
            months_covered: monthsCovered,
            payment_type: 'jumaa_subscription',
          },
        }),
      },
    );

    const paystackResult = await paystackResponse.json();

    if (!paystackResponse.ok || !paystackResult.status) {
      console.error('Paystack charge error:', paystackResult);

      await supabaseFetch(
        `subscription_payments?reference=eq.${encodeURIComponent(
          reference,
        )}`,
        {
          method: 'PATCH',
          body: JSON.stringify({
            status: 'failed',
          }),
        },
      );

      return jsonResponse(
        {
          success: false,
          error:
            paystackResult?.message ??
            'Paystack could not initiate the M-PESA payment.',
          reference,
        },
        400,
      );
    }

    const paystackData = paystackResult.data ?? {};

    // ----------------------------------------------------------
    // 9. Mark payment as processing
    // ----------------------------------------------------------

    await supabaseFetch(
      `subscription_payments?reference=eq.${encodeURIComponent(
        reference,
      )}`,
      {
        method: 'PATCH',
        body: JSON.stringify({
          status: 'processing',
        }),
      },
    );

    return jsonResponse({
      success: true,
      reference,
      unit_count: unitCount,
      monthly_rate: monthlyRate,
      amount: requestedAmount,
      months_covered: monthsCovered,
      paystack_status: paystackData.status ?? null,
      display_text:
        paystackData.display_text ??
        'Please check your phone and complete the M-PESA payment.',
    });
  } catch (error) {
    console.error('CREATE SUBSCRIPTION PAYMENT ERROR:', error);

    return jsonResponse(
      {
        success: false,
        error:
          error instanceof Error
            ? error.message
            : String(error),
      },
      500,
    );
  }
});
