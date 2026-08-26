import { corsHeaders } from '../_shared/cors.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY')!;
const EMAIL_FROM =
  Deno.env.get('EMAIL_FROM') ?? 'JUMAA <your-verified-email@example.com>';

interface TenantRequest {
  tenant_id: string;
  full_name: string;
  email: string;
  phone: string;
  apartment: string;
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

    const body: TenantRequest = await req.json();

    if (
      !body.tenant_id ||
      !body.full_name ||
      !body.email ||
      !body.phone
    ) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'tenant_id, full_name, email and phone are required.',
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
    // 1. Verify that the tenant record exists.
    // ----------------------------------------------------------
    const tenantResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/tenants?id=eq.${encodeURIComponent(body.tenant_id)}&select=id,property_id,unit_id,full_name,email,phone,account_status`,
      {
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
      },
    );

    if (!tenantResponse.ok) {
      throw new Error('Could not verify the tenant record.');
    }

    const tenants = await tenantResponse.json();

    if (!Array.isArray(tenants) || tenants.length === 0) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Tenant record was not found.',
        }),
        {
          status: 404,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const tenant = tenants[0];

    // ----------------------------------------------------------
    // 2. Check whether a profile already exists.
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
      throw new Error('Could not check the tenant profile.');
    }

    const existingProfiles = await profileResponse.json();

    if (Array.isArray(existingProfiles) && existingProfiles.length > 0) {
      const profile = existingProfiles[0];

      if (profile.role != 'tenant') {
        throw new Error(
          'This email is already registered to another account type.',
        );
      }

      return new Response(
        JSON.stringify({
          success: false,
          error: 'A tenant account already exists for this email.',
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
    // 3. Create the Supabase Auth account.
    // ----------------------------------------------------------
    const temporaryPassword =
      `Jumaa@${crypto.randomUUID().replaceAll('-', '').substring(0, 12)}`;

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
            role: 'tenant',
            tenant_id: body.tenant_id,
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
            'Could not create the tenant Auth account.',
      );
    }

    const authUserId = createdUser.id;

    if (!authUserId) {
      throw new Error('Supabase did not return the new tenant user ID.');
    }

    // ----------------------------------------------------------
    // 3.5 Link the tenant record to the Supabase Auth user.
    // ----------------------------------------------------------
    const tenantLinkResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/tenants?id=eq.${encodeURIComponent(body.tenant_id)}`,
      {
        method: 'PATCH',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
          Prefer: 'return=minimal',
        },
        body: JSON.stringify({
          auth_user_id: authUserId,
        }),
      },
    );

    if (!tenantLinkResponse.ok) {
      const tenantLinkError = await tenantLinkResponse.text();

      console.error(
        'Tenant auth_user_id update failed:',
        tenantLinkError,
      );

      throw new Error(
        'Tenant Auth account was created, but the tenant record could not be linked to the Auth account.',
      );
    }

    // ----------------------------------------------------------
    // 4. Create the tenant profile.
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
          role: 'tenant',
          must_reset_password: true,
          mfa_required: true,
        }),
      },
    );

    if (!profileUpsertResponse.ok) {
      const profileError = await profileUpsertResponse.text();
      console.error('Profile creation error:', profileError);
      throw new Error('Tenant Auth account was created, but profile creation failed.');
    }

    // ----------------------------------------------------------
    // 5. Send invitation through Brevo.
    // ----------------------------------------------------------
    const safeName = escapeHtml(body.full_name);
    const safeEmail = escapeHtml(email);
    const safePassword = escapeHtml(temporaryPassword);
    const safeApartment = escapeHtml(body.apartment || 'Your assigned unit');

    const emailResponse = await fetch(
      'https://api.brevo.com/v3/smtp/email',
      {
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
              email,
              name: body.full_name,
            },
          ],
          subject: 'Your JUMAA Tenant Account Invitation',
          htmlContent: `
<!DOCTYPE html>
<html>
<body style="font-family:Arial,sans-serif;background:#f5f7f6;padding:24px;">
  <div style="max-width:600px;margin:auto;background:#ffffff;padding:30px;border-radius:14px;">
    <h2 style="color:#0B3D2E;">Welcome to JUMAA</h2>

    <p>Hello <strong>${safeName}</strong>,</p>

    <p>
      Your landlord has created a JUMAA tenant account for you.
    </p>

    <p>
      Your assigned unit is:
      <strong>${safeApartment}</strong>
    </p>

    <div style="background:#eef5f1;padding:20px;border-radius:10px;margin:25px 0;">
      <p><strong>Email:</strong> ${safeEmail}</p>
      <p><strong>Temporary password:</strong> ${safePassword}</p>
    </div>

    <p>
      Use these credentials to log in to the JUMAA app.
      You will be required to change your temporary password.
    </p>

    <p>
      Please keep your login details private.
    </p>

    <p style="margin-top:30px;">
      Regards,<br>
      <strong>JUMAA</strong>
    </p>
  </div>
</body>
</html>
`,
        }),
      },
    );

    const emailResult = await emailResponse.json();

    if (!emailResponse.ok) {
      console.error('Brevo invitation error:', emailResult);

      return new Response(
        JSON.stringify({
          success: false,
          account_created: true,
          profile_created: true,
          email_sent: false,
          error: 'Tenant account was created, but the invitation email could not be sent.',
        }),
        {
          status: 502,
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
        account_created: true,
        profile_created: true,
        email_sent: true,
        tenant_id: tenant.id,
        user_id: authUserId,
        messageId: emailResult.messageId ?? null,
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
    console.error('Tenant invitation error:', error);

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
