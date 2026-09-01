import { corsHeaders } from '../_shared/cors.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const BREVO_API_KEY = Deno.env.get('BREVO_API_KEY')!;
const EMAIL_FROM =
  Deno.env.get('EMAIL_FROM') ?? 'JUMAA <your-verified-email@example.com>';

type Action = 'mark' | 'suspend' | 'unsuspend' | 'delete';

interface RequestBody {
  action: Action;
  property_id: string;
  reason?: 'malfunction' | 'other' | 'subscription';
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      'Content-Type': 'application/json',
    },
  });
}

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

async function supabaseFetch(
  path: string,
  options: RequestInit = {},
): Promise<Response> {
  return fetch(`${SUPABASE_URL}${path}`, {
    ...options,
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      'Content-Type': 'application/json',
      ...(options.headers ?? {}),
    },
  });
}

async function sendEmail(
  to: string,
  subject: string,
  html: string,
): Promise<void> {
  if (!to || !to.trim()) return;

  const response = await fetch('https://api.brevo.com/v3/smtp/email', {
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
      to: [{ email: to.trim() }],
      subject,
      htmlContent: html,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    console.error('Brevo email error:', error);
    throw new Error('Failed to send notification email.');
  }
}

async function deleteAuthUser(userId: string | null | undefined) {
  if (!userId) return;

  const response = await supabaseFetch(
    `/auth/v1/admin/users/${encodeURIComponent(userId)}`,
    {
      method: 'DELETE',
    },
  );

  if (!response.ok) {
    const error = await response.text();

    console.error(
      `Failed to delete Auth user ${userId}:`,
      error,
    );

    throw new Error(
      `Failed to delete associated user account ${userId}.`,
    );
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: corsHeaders,
    });
  }

  try {
    // ----------------------------------------------------------
    // Basic configuration validation
    // ----------------------------------------------------------
    if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
      return json(
        {
          success: false,
          error: 'Supabase service credentials are not configured.',
        },
        500,
      );
    }

    if (!BREVO_API_KEY) {
      return json(
        {
          success: false,
          error: 'BREVO_API_KEY is not configured.',
        },
        500,
      );
    }

    // ----------------------------------------------------------
    // Authenticate the caller
    // ----------------------------------------------------------
    const authorization = req.headers.get('Authorization');

    if (!authorization?.startsWith('Bearer ')) {
      return json(
        {
          success: false,
          error: 'Authentication required.',
        },
        401,
      );
    }

    const accessToken = authorization.substring(7).trim();

    if (!accessToken) {
      return json(
        {
          success: false,
          error: 'Authentication required.',
        },
        401,
      );
    }

    // Verify the access token using Supabase Auth.
    const userResponse = await fetch(
      `${SUPABASE_URL}/auth/v1/user`,
      {
        headers: {
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${accessToken}`,
        },
      },
    );

    if (!userResponse.ok) {
      return json(
        {
          success: false,
          error: 'Invalid or expired authentication token.',
        },
        401,
      );
    }

    const caller = await userResponse.json();

    if (!caller?.id) {
      return json(
        {
          success: false,
          error: 'Could not identify authenticated user.',
        },
        401,
      );
    }

    // ----------------------------------------------------------
    // Verify JUMAA OWNER role
    // ----------------------------------------------------------
    const callerProfileResponse = await supabaseFetch(
      `/rest/v1/profiles?id=eq.${encodeURIComponent(caller.id)}&select=id,role&limit=1`,
    );

    if (!callerProfileResponse.ok) {
      throw new Error('Could not verify JUMAA Owner permissions.');
    }

    const callerProfiles = await callerProfileResponse.json();
    const callerProfile = callerProfiles?.[0];

    if (
      callerProfile?.role?.toString().toLowerCase().trim() !==
      'jumaa_owner'
    ) {
      return json(
        {
          success: false,
          error: 'Only a JUMAA Owner can perform this action.',
        },
        403,
      );
    }

    // ----------------------------------------------------------
    // Validate request
    // ----------------------------------------------------------
    const body: RequestBody = await req.json();

    if (!body.action || !body.property_id) {
      return json(
        {
          success: false,
          error: 'action and property_id are required.',
        },
        400,
      );
    }

    const validActions: Action[] = [
      'mark',
      'suspend',
      'unsuspend',
      'delete',
    ];

    if (!validActions.includes(body.action)) {
      return json(
        {
          success: false,
          error:
            'Invalid action. Use mark, suspend, unsuspend or delete.',
        },
        400,
      );
    }

    // ----------------------------------------------------------
    // Load property
    // ----------------------------------------------------------
    const propertyResponse = await supabaseFetch(
      `/rest/v1/properties?id=eq.${encodeURIComponent(body.property_id)}&select=*`,
    );

    if (!propertyResponse.ok) {
      throw new Error('Could not load the property.');
    }

    const properties = await propertyResponse.json();

    if (!Array.isArray(properties) || properties.length === 0) {
      return json(
        {
          success: false,
          error: 'Property not found.',
        },
        404,
      );
    }

    const property = properties[0];

    const propertyId = property.id;
    const propertyName =
      property.name?.toString() || 'JUMAA Property';

    const ownerId = property.owner_id || null;
    const landlordId = property.landlord_id || null;

    // ==========================================================
    // MARK
    // ==========================================================
    if (body.action === 'mark') {
      if (!body.reason) {
        return json(
          {
            success: false,
            error:
              'A reason is required when marking a property.',
          },
          400,
        );
      }

      const validReasons = [
        'malfunction',
        'other',
        'subscription',
      ];

      if (!validReasons.includes(body.reason)) {
        return json(
          {
            success: false,
            error: 'Invalid property action reason.',
          },
          400,
        );
      }

      const patchResponse = await supabaseFetch(
        `/rest/v1/properties?id=eq.${encodeURIComponent(propertyId)}`,
        {
          method: 'PATCH',
          headers: {
            Prefer: 'return=minimal',
          },
          body: JSON.stringify({
            marked_for_action: true,
            marked_reason: body.reason,
            marked_at: new Date().toISOString(),
            marked_by: caller.id,
          }),
        },
      );

      if (!patchResponse.ok) {
        const error = await patchResponse.text();

        console.error('Property mark error:', error);

        throw new Error('Could not mark the property.');
      }

      // --------------------------------------------------------
      // Find owner and landlord email addresses.
      // --------------------------------------------------------
      const recipientIds = [
        ownerId,
        landlordId,
      ].filter(
        (id): id is string => Boolean(id),
      );

      const uniqueRecipientIds = [
        ...new Set(recipientIds),
      ];

      const recipients: Array<{
        email: string;
        name: string;
      }> = [];

      for (const userId of uniqueRecipientIds) {
        const response = await supabaseFetch(
          `/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}&select=email,full_name&limit=1`,
        );

        if (!response.ok) continue;

        const profiles = await response.json();

        if (profiles?.[0]?.email) {
          recipients.push({
            email: profiles[0].email,
            name:
              profiles[0].full_name?.toString() || 'JUMAA User',
          });
        }
      }

      const reasonLabel =
        body.reason === 'malfunction'
          ? 'Malfunction'
          : body.reason === 'subscription'
            ? 'Subscription'
            : 'Other';

      const safePropertyName = escapeHtml(propertyName);

      for (const recipient of recipients) {
        await sendEmail(
          recipient.email,
          `Action required: ${propertyName} may be suspended soon`,
          `
            <div style="font-family:Arial,sans-serif;line-height:1.6">
              <h2>JUMAA Property Action Required</h2>

              <p>Hello ${escapeHtml(recipient.name)},</p>

              <p>
                Your property
                <strong>${safePropertyName}</strong>
                has been marked for action by JUMAA.
              </p>

              <p>
                <strong>Reason:</strong>
                ${escapeHtml(reasonLabel)}
              </p>

              <p>
                Please take action quickly.
                Your property will be suspended soon due to
                <strong>${escapeHtml(reasonLabel)}</strong>
                and you will not be able to access all JUMAA services.
              </p>

              <p>
                Please resolve the issue before the property is suspended.
              </p>

              <p>
                Regards,<br>
                <strong>JUMAA</strong>
              </p>
            </div>
          `,
        );
      }

      return json({
        success: true,
        action: 'mark',
        property_id: propertyId,
        reason: body.reason,
        emails_sent: recipients.length,
      });
    }

    // ==========================================================
    // SUSPEND
    // ==========================================================
    if (body.action === 'suspend') {
      const reason =
        body.reason ||
        property.suspension_reason ||
        property.marked_reason ||
        'other';

      const patchResponse = await supabaseFetch(
        `/rest/v1/properties?id=eq.${encodeURIComponent(propertyId)}`,
        {
          method: 'PATCH',
          headers: {
            Prefer: 'return=minimal',
          },
          body: JSON.stringify({
            is_suspended: true,
            suspended_at: new Date().toISOString(),
            suspended_by: caller.id,
            suspension_reason: reason,
          }),
        },
      );

      if (!patchResponse.ok) {
        const error = await patchResponse.text();

        console.error('Property suspension error:', error);

        throw new Error('Could not suspend the property.');
      }

      const recipientIds = [
        ownerId,
        landlordId,
      ].filter(
        (id): id is string => Boolean(id),
      );

      const uniqueRecipientIds = [
        ...new Set(recipientIds),
      ];

      const recipients: Array<{
        email: string;
        name: string;
      }> = [];

      for (const userId of uniqueRecipientIds) {
        const response = await supabaseFetch(
          `/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}&select=email,full_name&limit=1`,
        );

        if (!response.ok) continue;

        const profiles = await response.json();

        if (profiles?.[0]?.email) {
          recipients.push({
            email: profiles[0].email,
            name:
              profiles[0].full_name?.toString() || 'JUMAA User',
          });
        }
      }

      const reasonLabel =
        reason === 'malfunction'
          ? 'Malfunction'
          : reason === 'subscription'
            ? 'Subscription'
            : 'Other';

      const safePropertyName = escapeHtml(propertyName);

      for (const recipient of recipients) {
        await sendEmail(
          recipient.email,
          `JUMAA property suspended: ${propertyName}`,
          `
            <div style="font-family:Arial,sans-serif;line-height:1.6">
              <h2>JUMAA Property Suspended</h2>

              <p>Hello ${escapeHtml(recipient.name)},</p>

              <p>
                Your property
                <strong>${safePropertyName}</strong>
                has been suspended by JUMAA.
              </p>

              <p>
                <strong>Reason:</strong>
                ${escapeHtml(reasonLabel)}
              </p>

              <p>
                Your access to JUMAA services associated with this
                property has been restricted.
              </p>

              <p>
                Owner and landlord permissions have been downgraded.
                Tenants associated with this property are also restricted
                to their dashboard.
              </p>

              <p>
                Please contact JUMAA or resolve the issue before
                requesting restoration.
              </p>

              <p>
                Regards,<br>
                <strong>JUMAA</strong>
              </p>
            </div>
          `,
        );
      }

      return json({
        success: true,
        action: 'suspend',
        property_id: propertyId,
        reason,
        emails_sent: recipients.length,
      });
    }

    // ==========================================================
    // UNSUSPEND
    // ==========================================================
    if (body.action === 'unsuspend') {
      const patchResponse = await supabaseFetch(
        `/rest/v1/properties?id=eq.${encodeURIComponent(propertyId)}`,
        {
          method: 'PATCH',
          headers: {
            Prefer: 'return=minimal',
          },
          body: JSON.stringify({
            is_suspended: false,
            suspended_at: null,
            suspended_by: null,
            suspension_reason: null,
            marked_for_action: false,
            marked_reason: null,
            marked_at: null,
            marked_by: null,
          }),
        },
      );

      if (!patchResponse.ok) {
        const error = await patchResponse.text();

        console.error('Property unsuspension error:', error);

        throw new Error('Could not unsuspend the property.');
      }

      return json({
        success: true,
        action: 'unsuspend',
        property_id: propertyId,
      });
    }

    // ==========================================================
    // DELETE
    // ==========================================================
    //
    // We deliberately handle this ourselves instead of relying
    // entirely on database cascades because owner, landlord and
    // tenant Auth accounts must also be removed.
    // ==========================================================
    if (body.action === 'delete') {
      // --------------------------------------------------------
      // Find tenants belonging to this property.
      // --------------------------------------------------------
      const tenantsResponse = await supabaseFetch(
        `/rest/v1/tenants?property_id=eq.${encodeURIComponent(propertyId)}&select=id,auth_user_id,email,full_name`,
      );

      if (!tenantsResponse.ok) {
        throw new Error('Could not find property tenants.');
      }

      const tenants = await tenantsResponse.json();

      // --------------------------------------------------------
      // Find tenant assignment records too.
      // --------------------------------------------------------
      const assignmentsResponse = await supabaseFetch(
        `/rest/v1/tenant_assignments?property_id=eq.${encodeURIComponent(propertyId)}&select=id`,
      );

      if (!assignmentsResponse.ok) {
        throw new Error(
          'Could not inspect tenant assignments.',
        );
      }

      // --------------------------------------------------------
      // IMPORTANT:
        //
        // If the owner owns another property, do not delete the
        // owner's account. The requested property can still be
        // permanently deleted without destroying the owner's
        // other property.
        // --------------------------------------------------------
      let ownerHasOtherProperties = false;

      if (ownerId) {
        const otherPropertiesResponse = await supabaseFetch(
          `/rest/v1/properties?owner_id=eq.${encodeURIComponent(ownerId)}&id=neq.${encodeURIComponent(propertyId)}&select=id&limit=1`,
        );

        if (!otherPropertiesResponse.ok) {
          throw new Error(
            'Could not verify the owner property relationships.',
          );
        }

        const otherProperties =
          await otherPropertiesResponse.json();

        ownerHasOtherProperties =
          Array.isArray(otherProperties) &&
          otherProperties.length > 0;
      }

      // --------------------------------------------------------
      // If the landlord manages another property, don't delete
      // the landlord Auth account either.
      // --------------------------------------------------------
      let landlordHasOtherProperties = false;

      if (landlordId) {
        const otherPropertiesResponse = await supabaseFetch(
          `/rest/v1/properties?landlord_id=eq.${encodeURIComponent(landlordId)}&id=neq.${encodeURIComponent(propertyId)}&select=id&limit=1`,
        );

        if (!otherPropertiesResponse.ok) {
          throw new Error(
            'Could not verify the landlord property relationships.',
          );
        }

        const otherProperties =
          await otherPropertiesResponse.json();

        landlordHasOtherProperties =
          Array.isArray(otherProperties) &&
          otherProperties.length > 0;
      }

      // --------------------------------------------------------
      // Delete the property.
      //
      // Database ON DELETE CASCADE handles property-dependent
      // records such as:
      //
      // units
      // tenants
      // bookings
      // booking_requests
      // conversations
      // notifications
      // payments
      // images
      // rent settings
      // reminders
      // subscriptions
      // subscription payments
      //
      // where the remote schema defines the relationship with
      // ON DELETE CASCADE.
      // --------------------------------------------------------
      const deletePropertyResponse = await supabaseFetch(
        `/rest/v1/properties?id=eq.${encodeURIComponent(propertyId)}`,
        {
          method: 'DELETE',
          headers: {
            Prefer: 'return=minimal',
          },
        },
      );

      if (!deletePropertyResponse.ok) {
        const error = await deletePropertyResponse.text();

        console.error(
          'Property deletion database error:',
          error,
        );

        throw new Error(
          'Could not delete the property from the database.',
        );
      }

      // --------------------------------------------------------
      // Delete tenant Auth accounts.
      // --------------------------------------------------------
      let tenantsDeleted = 0;

      if (Array.isArray(tenants)) {
        for (const tenant of tenants) {
          if (tenant.auth_user_id) {
            await deleteAuthUser(tenant.auth_user_id);
            tenantsDeleted++;
          }
        }
      }

      // --------------------------------------------------------
      // Delete landlord Auth account only when it is not being
      // used by another property.
      // --------------------------------------------------------
      let landlordDeleted = false;

      if (
        landlordId &&
        !landlordHasOtherProperties
      ) {
        await deleteAuthUser(landlordId);
        landlordDeleted = true;
      }

      // --------------------------------------------------------
      // Delete owner Auth account only when this was the owner's
      // last property.
      // --------------------------------------------------------
      let ownerDeleted = false;

      if (
        ownerId &&
        !ownerHasOtherProperties
      ) {
        await deleteAuthUser(ownerId);
        ownerDeleted = true;
      }

      return json({
        success: true,
        action: 'delete',
        property_id: propertyId,
        property_name: propertyName,
        tenants_deleted: tenantsDeleted,
        landlord_deleted: landlordDeleted,
        owner_deleted: ownerDeleted,
        owner_retained_because_other_properties:
          ownerHasOtherProperties,
        landlord_retained_because_other_properties:
          landlordHasOtherProperties,
      });
    }

    return json(
      {
        success: false,
        error: 'Unsupported action.',
      },
      400,
    );
  } catch (error) {
    console.error('manage-jumaa-property error:', error);

    return json(
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
