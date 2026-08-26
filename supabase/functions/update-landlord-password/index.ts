import { corsHeaders } from '../_shared/cors.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

interface PasswordRequest {
  new_password: string;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders,
    });
  }

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error(
        'Supabase service credentials are not configured.',
      );
    }

    const authHeader = req.headers.get('Authorization');

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing authentication token.',
        }),
        {
          status: 401,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const accessToken = authHeader.substring('Bearer '.length).trim();

    // ----------------------------------------------------------
    // 1. Verify the currently signed-in user.
    // ----------------------------------------------------------
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
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Your login session is invalid or expired.',
        }),
        {
          status: 401,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      );
    }

    const user = await userResponse.json();

    if (!user?.id || !user?.email) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Could not identify the authenticated user.',
        }),
        {
          status: 401,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      );
    }

    // ----------------------------------------------------------
    // 2. Confirm this is actually a landlord account.
    // ----------------------------------------------------------
    const profileResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(
        user.id,
      )}&select=id,email,role,must_reset_password`,
      {
        headers: {
          apikey: SUPABASE_SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        },
      },
    );

    if (!profileResponse.ok) {
      throw new Error(
        'Could not verify the landlord profile.',
      );
    }

    const profiles = await profileResponse.json();

    if (!Array.isArray(profiles) || profiles.length === 0) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Landlord profile was not found.',
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

    const profile = profiles[0];

    if (profile.role?.toString().toLowerCase() !== 'landlord') {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'This account is not a landlord account.',
        }),
        {
          status: 403,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
          },
        },
      );
    }

    // ----------------------------------------------------------
    // 3. Read and validate the new password.
    // ----------------------------------------------------------
    const body: PasswordRequest = await req.json();

    const newPassword = body.new_password ?? '';

    if (newPassword.length < 8) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Password must be at least 8 characters.',
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

    // ----------------------------------------------------------
    // 4. Actually change the Supabase Auth password.
    // ----------------------------------------------------------
    const updateAuthResponse = await fetch(
      `${SUPABASE_URL}/auth/v1/admin/users/${encodeURIComponent(
        user.id,
      )}`,
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

    const updateAuthData = await updateAuthResponse.json();

    if (!updateAuthResponse.ok) {
      console.error(
        'Supabase Auth password update error:',
        updateAuthData,
      );

      throw new Error(
        updateAuthData?.message ??
          updateAuthData?.msg ??
          'Could not update the Supabase Auth password.',
      );
    }

    // ----------------------------------------------------------
    // 5. Mark the temporary-password requirement as completed.
    // ----------------------------------------------------------
    const profileUpdateResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(
        user.id,
      )}`,
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
      const profileError = await profileUpdateResponse.text();

      console.error(
        'Profile password-reset flag update error:',
        profileError,
      );

      throw new Error(
        'Password changed, but the account reset status could not be updated.',
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
    console.error(
      'UPDATE LANDLORD PASSWORD ERROR:',
      error,
    );

    return new Response(
      JSON.stringify({
        success: false,
        error:
          error instanceof Error
            ? error.message
            : 'Could not update the password.',
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
