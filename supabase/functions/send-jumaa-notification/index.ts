import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID");
const FIREBASE_CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL");
const FIREBASE_PRIVATE_KEY = Deno.env.get("FIREBASE_PRIVATE_KEY");

const BREVO_API_KEY = Deno.env.get("BREVO_API_KEY");
const EMAIL_FROM =
  Deno.env.get("EMAIL_FROM") ?? "your-verified-email@example.com";

interface BookingRequestPayload {
  booking_id: string;
}

interface NotificationPayload {
  notification_id: string;
}

function base64UrlEncode(data: Uint8Array): string {
  let binary = "";

  for (const byte of data) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/g, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");

  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);

  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }

  return bytes.buffer;
}

async function createGoogleAccessToken(): Promise<string> {
  if (!FIREBASE_CLIENT_EMAIL || !FIREBASE_PRIVATE_KEY) {
    throw new Error("Firebase credentials are not configured.");
  }

  const now = Math.floor(Date.now() / 1000);

  const header = base64UrlEncode(
    new TextEncoder().encode(
      JSON.stringify({
        alg: "RS256",
        typ: "JWT",
      }),
    ),
  );

  const payload = base64UrlEncode(
    new TextEncoder().encode(
      JSON.stringify({
        iss: FIREBASE_CLIENT_EMAIL,
        scope: "https://www.googleapis.com/auth/firebase.messaging",
        aud: "https://oauth2.googleapis.com/token",
        iat: now,
        exp: now + 3600,
      }),
    ),
  );

  const unsignedToken = `${header}.${payload}`;

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n")),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    new TextEncoder().encode(unsignedToken),
  );

  const jwt = `${unsignedToken}.${base64UrlEncode(new Uint8Array(signature))}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body:
      `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer` +
      `&assertion=${encodeURIComponent(jwt)}`,
  });

  const tokenResult = await tokenResponse.json();

  if (!tokenResponse.ok || !tokenResult.access_token) {
    console.error("Google OAuth error:", tokenResult);
    throw new Error("Failed to obtain Firebase access token.");
  }

  return tokenResult.access_token;
}

async function sendFcmNotification(
  token: string,
  title: string,
  message: string,
  data: Record<string, string>,
): Promise<void> {
  if (!FIREBASE_PROJECT_ID) {
    throw new Error("FIREBASE_PROJECT_ID is not configured.");
  }

  const accessToken = await createGoogleAccessToken();

  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: {
            title,
            body: message,
          },
          data,
          android: {
            priority: "high",
            notification: {
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              },
            },
          },
        },
      }),
    },
  );

  if (!response.ok) {
    const result = await response.text();
    console.error("FCM API error:", result);
    throw new Error(`FCM request failed with status ${response.status}`);
  }
}

async function sendBrevoEmail(
  to: string,
  subject: string,
  html: string,
): Promise<void> {
  if (!BREVO_API_KEY) {
    throw new Error("BREVO_API_KEY is not configured.");
  }

  const response = await fetch("https://api.brevo.com/v3/smtp/email", {
    method: "POST",
    headers: {
      "api-key": BREVO_API_KEY,
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      sender: {
        name: "JUMAA",
        email: EMAIL_FROM,
      },
      to: [{ email: to }],
      subject,
      htmlContent: html,
    }),
  });

  if (!response.ok) {
    const result = await response.text();
    console.error("Brevo API error:", result);
    throw new Error(`Brevo request failed with status ${response.status}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error("Supabase server configuration is missing.");
    }

    const body = await req.json();

    // Accept both direct calls and Supabase Database Webhook payloads.
    // ============================================================
    // OWNER REQUEST RESPONSE FLOW
    // Handles accepted/rejected requests from the JUMAA platform owner.
    // ============================================================
    const ownerRequestId = body?.owner_request_id;
    const ownerRequestAction = body?.action;

    if (
      ownerRequestId &&
      (ownerRequestAction === "accepted" || ownerRequestAction === "rejected")
    ) {
      const supabaseHeaders = {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
      };

      // Load the owner request.
      const requestResponse = await fetch(
        `${SUPABASE_URL}/rest/v1/owner_requests?id=eq.${encodeURIComponent(ownerRequestId)}&select=id,owner_id,request_type,subject,message,status,rejection_reason,requested_until`,
        {
          headers: supabaseHeaders,
        },
      );

      if (!requestResponse.ok) {
        throw new Error("Failed to load owner request.");
      }

      const requestRows = await requestResponse.json();

      if (!requestRows.length) {
        throw new Error("Owner request not found.");
      }

      const ownerRequest = requestRows[0];

      // Load the apartment owner's profile.
      const profileResponse = await fetch(
        `${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(ownerRequest.owner_id)}&select=id,full_name,email`,
        {
          headers: supabaseHeaders,
        },
      );

      if (!profileResponse.ok) {
        throw new Error("Failed to load apartment owner profile.");
      }

      const profiles = await profileResponse.json();

      if (!profiles.length) {
        throw new Error("Apartment owner profile not found.");
      }

      const owner = profiles[0];
      const ownerName = owner.full_name ?? "JUMAA Owner";
      const ownerEmail = owner.email;

      const requestSubject = ownerRequest.subject ?? "your JUMAA request";

      let title;
      let message;

      if (ownerRequestAction === "rejected") {
        const reason =
          ownerRequest.rejection_reason ?? "No reason was provided.";

        title = "JUMAA Request Rejected";
        message = `Your request "${requestSubject}" has been rejected. Reason: ${reason}`;
      } else {
        title = "JUMAA Request Accepted";
        message = `Your request "${requestSubject}" has been accepted by the JUMAA platform owner`;
      }

      // Create the owner's in-app notification.
      const notificationResponse = await fetch(
        `${SUPABASE_URL}/rest/v1/owner_notifications`,
        {
          method: "POST",
          headers: {
            ...supabaseHeaders,
            Prefer: "return=minimal",
          },
          body: JSON.stringify({
            owner_id: ownerRequest.owner_id,
            request_id: ownerRequest.id,
            title,
            message,
            notification_type: `owner_request_${ownerRequestAction}`,
            is_read: false,
          }),
        },
      );

      if (!notificationResponse.ok) {
        const result = await notificationResponse.text();
        console.error("Owner notification insert failed:", result);
      }

      // Load every registered device for the apartment owner.
      const tokenResponse = await fetch(
        `${SUPABASE_URL}/rest/v1/push_tokens?user_id=eq.${encodeURIComponent(ownerRequest.owner_id)}&select=id,token,platform`,
        {
          headers: supabaseHeaders,
        },
      );

      if (!tokenResponse.ok) {
        throw new Error("Failed to load owner push tokens.");
      }

      const tokens = await tokenResponse.json();

      const pushResults = [];

      for (const tokenRecord of tokens) {
        try {
          await sendFcmNotification(tokenRecord.token, title, message, {
            type: `owner_request_${ownerRequestAction}`,
            owner_request_id: String(ownerRequest.id),
          });

          pushResults.push({
            token_id: tokenRecord.id,
            success: true,
          });
        } catch (error) {
          console.error(`FCM failed for owner token ${tokenRecord.id}:`, error);

          pushResults.push({
            token_id: tokenRecord.id,
            success: false,
          });
        }
      }

      // Send the email through Brevo.
      let emailSent = false;

      if (ownerEmail) {
        try {
          const escapedName = String(ownerName)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");

          const escapedSubject = String(requestSubject)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");

          const escapedMessage = String(message)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");

          const emailSubject =
            ownerRequestAction === "rejected"
              ? `JUMAA Request Rejected — ${requestSubject}`
              : `JUMAA Request Accepted — ${requestSubject}`;

          await sendBrevoEmail(
            ownerEmail,
            emailSubject,
            `
              <div style="font-family:Arial,sans-serif;line-height:1.6">
                <h2>${title}</h2>
                <p>Hello <strong>${escapedName}</strong>,</p>
                <p>${escapedMessage}</p>
                <p>
                  <strong>Request:</strong> ${escapedSubject}
                </p>
                ${
                  ownerRequestAction === "rejected"
                    ? "<p>Please review the reason above and contact JUMAA if you need further assistance.</p>"
                    : "<p>Please open JUMAA to continue with the next steps.</p>"
                }
                <p style="margin-top:24px">
                  Regards,<br>
                  <strong>JUMAA</strong>
                </p>
              </div>
            `,
          );

          emailSent = true;
        } catch (error) {
          console.error("Owner request email failed:", error);
        }
      }

      return new Response(
        JSON.stringify({
          success: true,
          owner_request_id: ownerRequest.id,
          owner_id: ownerRequest.owner_id,
          action: ownerRequestAction,
          email_sent: emailSent,
          push_devices: tokens.length,
          push_results: pushResults,
        }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    // ============================================================
    // GENERIC NOTIFICATION EVENT
    // Handles rows inserted into public.notifications.
    // ============================================================
    const notificationId =
      body?.notification_id ?? body?.record?.id ?? body?.new?.id;

    const eventTable =
      body?.table ??
      body?.record?.table ??
      body?.new?.table ??
      body?.table_name;

    if (
      eventTable === "notifications" ||
      body?.type === "notification" ||
      body?.notification_id
    ) {
      if (!notificationId) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "notification_id could not be determined from the request.",
          }),
          {
            status: 400,
            headers: {
              ...corsHeaders,
              "Content-Type": "application/json",
            },
          },
        );
      }

      const supabaseHeaders = {
        apikey: SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
        "Content-Type": "application/json",
      };

      // Load the notification.
      const notificationResponse = await fetch(
        `${SUPABASE_URL}/rest/v1/notifications?id=eq.${encodeURIComponent(notificationId)}&select=id,user_id,property_id,title,message,type,is_read,sender_type,sender_name`,
        {
          headers: supabaseHeaders,
        },
      );

      if (!notificationResponse.ok) {
        throw new Error("Failed to load notification.");
      }

      const notificationRows = await notificationResponse.json();

      if (!notificationRows.length) {
        throw new Error("Notification not found.");
      }

      const notification = notificationRows[0];

      if (!notification.user_id) {
        throw new Error("Notification recipient could not be determined.");
      }

      const title = notification.title ?? "JUMAA Notification";
      const message = notification.message ?? "You have a new notification.";

      // Prevent duplicate push processing.
      const eventResponse = await fetch(
        `${SUPABASE_URL}/rest/v1/notification_events`,
        {
          method: "POST",
          headers: {
            ...supabaseHeaders,
            Prefer: "return=representation,resolution=ignore-duplicates",
          },
          body: JSON.stringify({
            event_type: "notification",
            event_id: notification.id,
          }),
        },
      );

      if (!eventResponse.ok) {
        const result = await eventResponse.text();
        console.error("Notification event registration failed:", result);
        throw new Error("Failed to register notification event.");
      }

      const registeredEvents = await eventResponse.json();

      if (!registeredEvents.length) {
        console.log(
          `Notification ${notification.id} has already been processed.`,
        );

        return new Response(
          JSON.stringify({
            success: true,
            duplicate: true,
            notification_id: notification.id,
          }),
          {
            status: 200,
            headers: {
              ...corsHeaders,
              "Content-Type": "application/json",
            },
          },
        );
      }

      // Find every device registered to the notification recipient.
      const tokenResponse = await fetch(
        `${SUPABASE_URL}/rest/v1/push_tokens?user_id=eq.${encodeURIComponent(notification.user_id)}&select=id,token,platform`,
        {
          headers: supabaseHeaders,
        },
      );

      if (!tokenResponse.ok) {
        throw new Error("Failed to load recipient push tokens.");
      }

      const tokens = await tokenResponse.json();

      const pushResults = [];

      for (const tokenRecord of tokens) {
        try {
          await sendFcmNotification(tokenRecord.token, title, message, {
            type: String(notification.type ?? "general"),
            notification_id: String(notification.id),
            property_id: String(notification.property_id ?? ""),
          });

          pushResults.push({
            token_id: tokenRecord.id,
            success: true,
          });
        } catch (error) {
          console.error(`FCM failed for token ${tokenRecord.id}:`, error);

          pushResults.push({
            token_id: tokenRecord.id,
            success: false,
          });
        }
      }

      return new Response(
        JSON.stringify({
          success: true,
          notification_id: notification.id,
          user_id: notification.user_id,
          push_devices: tokens.length,
          push_results: pushResults,
        }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    // ============================================================
    // EXISTING BOOKING REQUEST FLOW
    // ============================================================

    const bookingId = body?.booking_id ?? body?.record?.id ?? body?.new?.id;

    if (!bookingId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "booking_id could not be determined from the request.",
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const supabaseHeaders = {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
    };

    // 1. Load booking request.
    const bookingResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/booking_requests?id=eq.${encodeURIComponent(bookingId)}&select=id,property_id,unit_id,applicant_name,applicant_email,applicant_phone,status`,
      {
        headers: supabaseHeaders,
      },
    );

    if (!bookingResponse.ok) {
      throw new Error("Failed to load booking request.");
    }

    const bookings = await bookingResponse.json();

    if (!bookings.length) {
      throw new Error("Booking request not found.");
    }

    const booking = bookings[0];

    // 2. Prevent duplicate notifications if the webhook retries.
    const eventResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/notification_events`,
      {
        method: "POST",
        headers: {
          ...supabaseHeaders,
          Prefer: "return=representation,resolution=ignore-duplicates",
        },
        body: JSON.stringify({
          event_type: "booking_request",
          event_id: booking.id,
        }),
      },
    );

    if (!eventResponse.ok) {
      const result = await eventResponse.text();
      console.error("Notification event registration failed:", result);
      throw new Error("Failed to register notification event.");
    }

    const registeredEvents = await eventResponse.json();

    if (!registeredEvents.length) {
      console.log(`Booking ${booking.id} notification already processed.`);

      return new Response(
        JSON.stringify({
          success: true,
          duplicate: true,
          booking_id: booking.id,
        }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    // 3. Load property and landlord.
    const propertyResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/properties?id=eq.${encodeURIComponent(booking.property_id)}&select=id,name,landlord_id`,
      {
        headers: supabaseHeaders,
      },
    );

    if (!propertyResponse.ok) {
      throw new Error("Failed to load property.");
    }

    const properties = await propertyResponse.json();

    if (!properties.length || !properties[0].landlord_id) {
      throw new Error("Property landlord could not be determined.");
    }

    const property = properties[0];

    // 3. Resolve landlord Auth ID.
    const landlordResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/landlords?id=eq.${encodeURIComponent(property.landlord_id)}&select=id,auth_user_id,full_name,email`,
      {
        headers: supabaseHeaders,
      },
    );

    if (!landlordResponse.ok) {
      throw new Error("Failed to load landlord.");
    }

    const landlords = await landlordResponse.json();

    if (!landlords.length) {
      throw new Error("Landlord not found.");
    }

    const landlord = landlords[0];
    const landlordAuthId = landlord.auth_user_id ?? landlord.id;

    if (!landlordAuthId) {
      throw new Error("Landlord Auth ID could not be determined.");
    }

    // 4. Load exact unit.
    const unitResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/units?id=eq.${encodeURIComponent(booking.unit_id)}&select=id,unit_number,unit_type`,
      {
        headers: supabaseHeaders,
      },
    );

    if (!unitResponse.ok) {
      throw new Error("Failed to load unit.");
    }

    const units = await unitResponse.json();

    const unit = units.length ? units[0] : null;
    const unitLabel = unit?.unit_number
      ? `Unit ${unit.unit_number}`
      : "your apartment unit";

    const propertyName = property.name ?? "your property";

    const title = "🏠 New Booking Request";
    const message = `${booking.applicant_name} requested ${unitLabel} at ${propertyName}.`;

    // 5. Create in-app notification.
    const notificationResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/notifications`,
      {
        method: "POST",
        headers: {
          ...supabaseHeaders,
          Prefer: "return=minimal",
        },
        body: JSON.stringify({
          user_id: landlordAuthId,
          property_id: booking.property_id,
          title,
          message,
          type: "booking_request",
          is_read: false,
          sender_type: "jumaa",
          sender_name: "JUMAA",
        }),
      },
    );

    if (!notificationResponse.ok) {
      const result = await notificationResponse.text();
      console.error("Notification insert failed:", result);
    }

    // 6. Get all registered landlord devices.
    const tokenResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/push_tokens?user_id=eq.${encodeURIComponent(landlordAuthId)}&select=id,token,platform`,
      {
        headers: supabaseHeaders,
      },
    );

    if (!tokenResponse.ok) {
      throw new Error("Failed to load landlord push tokens.");
    }

    const tokens = await tokenResponse.json();

    // 7. Send push to every registered device.
    const pushResults = [];

    for (const tokenRecord of tokens) {
      try {
        await sendFcmNotification(tokenRecord.token, title, message, {
          type: "booking_request",
          booking_id: String(booking.id),
          property_id: String(booking.property_id),
          unit_id: String(booking.unit_id),
        });

        pushResults.push({
          token_id: tokenRecord.id,
          success: true,
        });
      } catch (error) {
        console.error(`FCM failed for token ${tokenRecord.id}:`, error);

        pushResults.push({
          token_id: tokenRecord.id,
          success: false,
        });
      }
    }

    // 8. Send email.
    let emailSent = false;

    if (landlord.email) {
      try {
        await sendBrevoEmail(
          landlord.email,
          `${title} — ${propertyName}`,
          `
            <div style="font-family:Arial,sans-serif;line-height:1.6">
              <h2>${title}</h2>
              <p>Hello ${landlord.full_name ?? "Landlord"},</p>
              <p>
                You have received a new booking request.
              </p>
              <p>
                <strong>Applicant:</strong> ${booking.applicant_name}<br>
                <strong>Unit:</strong> ${unitLabel}<br>
                <strong>Property:</strong> ${propertyName}
              </p>
              <p>
                Please open JUMAA to review the booking request.
              </p>
            </div>
          `,
        );

        emailSent = true;
      } catch (error) {
        console.error("Booking email failed:", error);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        booking_id: booking.id,
        landlord_id: landlord.id,
        landlord_auth_user_id: landlordAuthId,
        notification_created: notificationResponse.ok,
        push_devices: tokens.length,
        push_results: pushResults,
        email_sent: emailSent,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  } catch (error) {
    console.error("JUMAA notification error:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : String(error),
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      },
    );
  }
});
