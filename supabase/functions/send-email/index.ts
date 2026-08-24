import { corsHeaders } from '../_shared/cors.ts';

const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY');
const EMAIL_FROM = Deno.env.get('EMAIL_FROM') ?? 'JUMAA <your-verified-email@example.com>';

interface EmailRequest {
  to: string;
  subject: string;
  html: string;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders,
    });
  }

  try {
    if (!BREVO_API_KEY) {
      throw new Error('BREVO_API_KEY is not configured.');
    }

    const body: EmailRequest = await req.json();

    if (!body.to || !body.subject || !body.html) {
      return new Response(
        JSON.stringify({
          error: 'to, subject and html are required',
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const response = await fetch('https://api.brevo.com/v3/smtp/email', {
      method: 'POST',
      headers: {
        'api-key': BREVO_API_KEY,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({
        sender: {
          name: 'JUMAA',
          email: EMAIL_FROM,
        },
        to: [
          {
            email: body.to,
          },
        ],
        subject: body.subject,
        htmlContent: body.html,
      }),
    });

    const result = await response.json();

    if (!response.ok) {
      console.error('Brevo API error:', result);

      return new Response(
        JSON.stringify({
          error: result,
        }),
        {
          status: response.status,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        messageId: result.messageId,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      },
    );
  } catch (error) {
    console.error(error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
        },
      },
    );
  }
});
