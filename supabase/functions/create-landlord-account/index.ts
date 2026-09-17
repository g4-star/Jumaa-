import { corsHeaders } from '../_shared/cors.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY')!;
const EMAIL_FROM =
  Deno.env.get('EMAIL_FROM') ?? 'JUMAA <your-verified-email@example.com>';

interface LandlordRequest {
  full_name: string;
  email: string;
  phone: string;
  property_id: string;
  property_name: string;
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error('Supabase service credentials are not configured.');
    }

    if (!BREVO_API_KEY) {
      throw new Error('BREVO_API_KEY is not configured.');
    }

    const body: LandlordRequest = await req.json();

    if (
      !body.full_name ||
      !body.email ||
      !body.phone ||
      !body.property_id ||
      !body.property_name
    ) {
      return new Response(
        JSON.stringify({
          success: false,
          error:
            'full_name, email, phone, property_id and property_name are required.',
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

    const email = body.email.trim().toLowerCase();

    // ----------------------------------------------------------
    // 1. Check whether this email already has a profile.
    // ----------------------------------------------------------
    const profileResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles?email=eq.${encodeURIComponent(email)}&select=id,email,role`,
      {
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
      },
    );

    if (!profileResponse.ok) {
      throw new Error('Could not check the existing account.');
    }

    const existingProfiles = await profileResponse.json();

    if (Array.isArray(existingProfiles) && existingProfiles.length > 0) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'An account already exists for this email.',
          existing: true,
        }),
        {
          status: 409,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      );
    }

    // ----------------------------------------------------------
    // 2. Generate the REAL temporary Supabase Auth password.
    // ----------------------------------------------------------
    const temporaryPassword =
      `Jumaa@${crypto.randomUUID().replaceAll('-', '').substring(0, 12)}`;

    // ----------------------------------------------------------
    // 3. Create the real Supabase Auth account.
    // ----------------------------------------------------------
    const createUserResponse = await fetch(
      `${SUPABASE_URL}/auth/v1/admin/users`,
      {
        method: 'POST',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          email,
          password: temporaryPassword,
          email_confirm: true,
          user_metadata: {
            full_name: body.full_name,
            phone: body.phone,
            role: 'landlord',
            property_id: body.property_id,
            property_name: body.property_name,
          },
        }),
      },
    );

    const createdUser = await createUserResponse.json();

    if (!createUserResponse.ok) {
      console.error('Supabase Auth error:', createdUser);

      throw new Error(
        createdUser?.message ??
          createdUser?.msg ??
          'Could not create the landlord Auth account.',
      );
    }

    const authUserId = createdUser.id;

    if (!authUserId) {
      throw new Error(
        'Supabase did not return the new landlord user ID.',
      );
    }

    // ----------------------------------------------------------
    // 4. Create the landlord profile.
    // ----------------------------------------------------------
    const profileUpsertResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles`,
      {
        method: 'POST',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
          Prefer: 'resolution=merge-duplicates',
        },
        body: JSON.stringify({
          id: authUserId,
          email,
          full_name: body.full_name,
          phone: body.phone,
          role: 'landlord',
          must_reset_password: true,
          mfa_required: false,
        }),
      },
    );

    if (!profileUpsertResponse.ok) {
      const profileError = await profileUpsertResponse.text();

      console.error('Landlord profile creation error:', profileError);

      // Roll back Auth account if profile creation failed.
      await fetch(
        `${SUPABASE_URL}/auth/v1/admin/users/${authUserId}`,
        {
          method: 'DELETE',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          },
        },
      );

      throw new Error(
        'Landlord Auth account was created, but profile creation failed.',
      );
    }

    // ----------------------------------------------------------
    // 5. Create the landlord record.
    //
    // The landlord ID is the same as the Supabase Auth user ID.
    // This is required by public.landlords.id -> auth.users.id.
    // ----------------------------------------------------------
    const landlordResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/landlords`,
      {
        method: 'POST',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
          Prefer: 'return=minimal',
        },
        body: JSON.stringify({
          id: authUserId,
          full_name: body.full_name,
          email,
          phone: body.phone,
        }),
      },
    );

    if (!landlordResponse.ok) {
      const landlordError = await landlordResponse.text();

      console.error('Landlord record creation error:', landlordError);

      // Roll back the profile first.
      await fetch(
        `${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(authUserId)}`,
        {
          method: 'DELETE',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          },
        },
      );

      // Then roll back the Auth account.
      await fetch(
        `${SUPABASE_URL}/auth/v1/admin/users/${authUserId}`,
        {
          method: 'DELETE',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          },
        },
      );

      throw new Error(
        'Landlord Auth account and profile were created, but landlord record creation failed.',
      );
    }

    // ----------------------------------------------------------
    // 6. Assign the entire property to this landlord.
    //
    // The landlord manages the property as a whole, including
    // every unit belonging to that property.
    // ----------------------------------------------------------
    const propertyResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/properties?id=eq.${encodeURIComponent(body.property_id)}`,
      {
        method: 'PATCH',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
          Prefer: 'return=minimal',
        },
        body: JSON.stringify({
          landlord_id: authUserId,
        }),
      },
    );

    if (!propertyResponse.ok) {
      const propertyError = await propertyResponse.text();

      console.error('Property landlord assignment error:', propertyError);

      // Roll back the landlord record.
      await fetch(
        `${SUPABASE_URL}/rest/v1/landlords?id=eq.${encodeURIComponent(authUserId)}`,
        {
          method: 'DELETE',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          },
        },
      );

      // Roll back the profile.
      await fetch(
        `${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(authUserId)}`,
        {
          method: 'DELETE',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          },
        },
      );

      // Roll back the Auth account.
      await fetch(
        `${SUPABASE_URL}/auth/v1/admin/users/${authUserId}`,
        {
          method: 'DELETE',
          headers: {
            apikey: SUPABASE_SERVICE_ROLE_KEY,
            Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          },
        },
      );

      throw new Error(
        'Landlord account was created, but the property could not be assigned.',
      );
    }

    // ----------------------------------------------------------
    // 7. Send the temporary credentials through Brevo.
    // ----------------------------------------------------------
    const safeName = escapeHtml(body.full_name);
    const safeEmail = escapeHtml(email);
    const safePassword = escapeHtml(temporaryPassword);
    const safeProperty = escapeHtml(
      body.property_name || 'Your assigned property',
    );

    const emailResponse = await fetch(
      'https://api.brevo.com/v3/smtp/email',
      {
        method: 'POST',
        headers: {
          'api-key': BREVO_API_KEY,
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify({
          sender: {
            name: 'JUMAA',
            email: EMAIL_FROM,
          },
          to: [
            {
              email,
              name: body.full_name,
            },
          ],
          subject: 'Your JUMAA Landlord Account',
          htmlContent: `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>JUMAA</title>
</head>
<body style="margin:0;padding:0;background:#f4f7f5;font-family:Arial,Helvetica,sans-serif;color:#1f2937;">
  <div style="width:100%;padding:32px 12px;box-sizing:border-box;">
    <div style="max-width:620px;margin:0 auto;background:#ffffff;border-radius:18px;overflow:hidden;box-shadow:0 4px 18px rgba(0,0,0,0.08);">

      <div style="background:#0B3D2E;padding:28px 24px;text-align:center;">
        <img
          src="https://pdezijwjfqyulkkuhoun.supabase.co/storage/v1/object/public/email-assets/JUMAA.jpeg"
          alt="JUMAA"
          width="82"
          height="82"
          style="display:block;margin:0 auto 14px;width:82px;height:82px;border-radius:18px;object-fit:cover;background:#ffffff;"
        >
        <div style="font-size:25px;font-weight:700;color:#ffffff;letter-spacing:1px;">
          JUMAA
        </div>
        <div style="font-size:13px;color:#d7ebe3;margin-top:5px;">
          Join - Unite - Move - Access - Anywhere
        </div>
      </div>

      <div style="padding:32px 30px;">
        <div>
          
<!DOCTYPE html>
<html>
<body style="font-family:Arial,sans-serif;background:#f5f7f6;padding:30px;">
  <div style="max-width:600px;margin:auto;background:white;padding:30px;border-radius:16px;">
    <h2 style="color:#0B3D2E;">Welcome to JUMAA</h2>

    <p>Hello ${safeName},</p>

    <p>Your landlord account has been created successfully.</p>

    <p><strong>Property:</strong> ${safeProperty}</p>

    <p><strong>Email:</strong> ${safeEmail}</p>

    <div style="background:#E8F3EF;padding:20px;border-radius:12px;margin:20px 0;">
      <p style="margin:0 0 8px;"><strong>Temporary password</strong></p>
      <p style="font-size:22px;font-weight:bold;color:#0B3D2E;margin:0;">
        ${safePassword}
      </p>
    </div>

    <p>
      Use this temporary password to sign in to JUMAA.
      You will be required to create a new password after signing in.
    </p>

    <p>Please keep your login credentials secure.</p>

    <p>Regards,<br><strong>JUMAA</strong></p>
  </div>
</body>
</html>
          
        </div>
      </div>

      <div style="border-top:1px solid #e5e7eb;padding:22px 24px;text-align:center;background:#fafcfb;">
        <div style="font-weight:700;color:#0B3D2E;font-size:15px;">
          JUMAA
        </div>
        <div style="font-size:12px;color:#6b7280;margin-top:6px;">
          Join - Unite - Move - Access - Anywhere
        </div>
        <div style="font-size:11px;color:#9ca3af;margin-top:12px;">
          This is an automated email from JUMAA.
        </div>
      </div>

    </div>
  </div>
</body>
</html>
`,
        }),
      },
    );

    if (!emailResponse.ok) {
      const emailError = await emailResponse.text();

      console.error('Brevo error:', emailError);

      return new Response(
        JSON.stringify({
          success: true,
          auth_created: true,
          profile_created: true,
          email_sent: false,
          temporary_password: temporaryPassword,
          auth_user_id: authUserId,
          warning:
            'Landlord account was created, but the invitation email could not be sent.',
        }),
        {
          status: 200,
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
        auth_created: true,
        profile_created: true,
        email_sent: true,
        temporary_password: temporaryPassword,
        auth_user_id: authUserId,
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
    console.error('create-landlord-account error:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error:
          error instanceof Error
            ? error.message
            : 'Unexpected error.',
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
