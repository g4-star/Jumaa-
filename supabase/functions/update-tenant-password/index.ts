import { corsHeaders } from '../_shared/cors.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error('Supabase service credentials are not configured.');
    }

    const authHeader = req.headers.get('Authorization');

    if (!authHeader) {
      throw new Error('Authentication is required.');
    }

    const accessToken = authHeader.replace('Bearer ', '').trim();

    if (!accessToken) {
      throw new Error('Authentication is required.');
    }

    // Verify the currently signed-in user.
    const userResponse = await fetch(
      `${SUPABASE_URL}/auth/v1/user`,
      {
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${accessToken}`,
        },
      },
    );

    if (!userResponse.ok) {
      throw new Error('Your session is invalid or has expired.');
    }

    const user = await userResponse.json();
    const userId = user?.id;

    if (!userId) {
      throw new Error('Could not identify the authenticated user.');
    }

    // Confirm this is a tenant account.
    const profileResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}&select=id,role,must_reset_password`,
      {
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
      },
    );

    if (!profileResponse.ok) {
      throw new Error('Could not verify your tenant profile.');
    }

    const profiles = await profileResponse.json();

    if (!Array.isArray(profiles) || profiles.length === 0) {
      throw new Error('Tenant profile was not found.');
    }

    const profile = profiles[0];

    if (profile.role !== 'tenant') {
      throw new Error('This account is not registered as a tenant.');
    }

    const body = await req.json();
    const newPassword = String(body?.new_password ?? '');

    if (newPassword.length < 8) {
      throw new Error(
        'Your new password must be at least 8 characters.',
      );
    }

    // Update the authenticated user's password.
    const updateUserResponse = await fetch(
      `${SUPABASE_URL}/auth/v1/admin/users/${encodeURIComponent(userId)}`,
      {
        method: 'PUT',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          password: newPassword,
        }),
      },
    );

    if (!updateUserResponse.ok) {
      const errorText = await updateUserResponse.text();

      console.error(
        'Tenant password update failed:',
        errorText,
      );

      throw new Error('Could not update your password.');
    }

    // Mark the temporary-password requirement as completed.
    const profileUpdateResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}`,
      {
        method: 'PATCH',
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json',
          Prefer: 'return=minimal',
        },
        body: JSON.stringify({
          must_reset_password: false,
        }),
      },
    );

    if (!profileUpdateResponse.ok) {
      const errorText = await profileUpdateResponse.text();

      console.error(
        'Tenant profile update failed:',
        errorText,
      );

      throw new Error(
        'Password was changed, but the tenant profile could not be updated.',
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Password updated successfully.',
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
    console.error('UPDATE TENANT PASSWORD ERROR:', error);

    return new Response(
      JSON.stringify({
        success: false,
        error:
          error instanceof Error
            ? error.message
            : 'Could not update your password.',
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
});
