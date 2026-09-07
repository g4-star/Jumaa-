import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error("Supabase environment variables are not configured.");
    }

    // ------------------------------------------------------------
    // 1. Authenticate the caller.
    // ------------------------------------------------------------

    const authHeader = req.headers.get("Authorization");

    if (!authHeader?.startsWith("Bearer ")) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Authentication is required.",
        }),
        {
          status: 401,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const jwt = authHeader.replace("Bearer ", "").trim();

    const supabase = createClient(
      SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY,
      {
        global: {
          headers: {
            Authorization: `Bearer ${jwt}`,
          },
        },
      },
    );

    const {
      data: { user: caller },
      error: callerError,
    } = await supabase.auth.getUser(jwt);

    if (callerError || !caller) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Invalid or expired authentication session.",
        }),
        {
          status: 401,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    // ------------------------------------------------------------
    // 2. Parse request.
    // ------------------------------------------------------------

    const body = await req.json();

    const tenantId = body?.tenant_id?.toString().trim() ?? "";

    if (!tenantId) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "tenant_id is required.",
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

    // ------------------------------------------------------------
    // 3. Use service-role client for administrative operations.
    // ------------------------------------------------------------

    const admin = createClient(
      SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY,
    );

    // ------------------------------------------------------------
    // 4. Find the tenant using the exact tenant ID.
    // ------------------------------------------------------------

    const { data: tenant, error: tenantError } = await admin
      .from("tenants")
      .select(
        "id, property_id, unit_id, auth_user_id, full_name, email",
      )
      .eq("id", tenantId)
      .maybeSingle();

    if (tenantError) {
      throw new Error(
        `Failed to find tenant: ${tenantError.message}`,
      );
    }

    if (!tenant) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Tenant record was not found.",
        }),
        {
          status: 404,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    const propertyId = tenant.property_id?.toString() ?? "";
    const unitId = tenant.unit_id?.toString() ?? "";
    const authUserId = tenant.auth_user_id?.toString() ?? "";

    // ------------------------------------------------------------
    // 5. Verify caller is the landlord assigned to this property.
    // ------------------------------------------------------------

    const { data: property, error: propertyError } = await admin
      .from("properties")
      .select("id, landlord_id")
      .eq("id", propertyId)
      .maybeSingle();

    if (propertyError) {
      throw new Error(
        `Failed to verify property ownership: ${propertyError.message}`,
      );
    }

    if (!property) {
      throw new Error("Tenant property was not found.");
    }

    let callerIsLandlord = false;

    if (property.landlord_id?.toString() === caller.id) {
      callerIsLandlord = true;
    }

    if (!callerIsLandlord) {
      const { data: landlord } = await admin
        .from("landlords")
        .select("id, auth_user_id")
        .or(
          `id.eq.${caller.id},auth_user_id.eq.${caller.id}`,
        )
        .maybeSingle();

      if (
        landlord &&
        (
          landlord.id?.toString() === property.landlord_id?.toString() ||
          landlord.auth_user_id?.toString() === caller.id
        )
      ) {
        callerIsLandlord = true;
      }
    }

    if (!callerIsLandlord) {
      return new Response(
        JSON.stringify({
          success: false,
          error:
            "You are not authorized to delete tenants from this property.",
        }),
        {
          status: 403,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    // ------------------------------------------------------------
    // 6. Prevent accidental deletion of caller.
    // ------------------------------------------------------------

    if (authUserId && authUserId === caller.id) {
      throw new Error(
        "You cannot delete the account currently in use.",
      );
    }

    // ------------------------------------------------------------
    // 7. Delete tenant's booking requests.
    //
    // booking_requests does not have tenant_id, so remove requests
    // belonging to this tenant using the tenant's email.
    // ------------------------------------------------------------

    const tenantEmail =
      tenant.email?.toString().trim().toLowerCase() ?? "";

    if (tenantEmail) {
      const { error: bookingDeleteError } = await admin
        .from("booking_requests")
        .delete()
        .eq("property_id", propertyId)
        .ilike("applicant_email", tenantEmail);

      if (bookingDeleteError) {
        console.warn(
          "Booking request cleanup warning:",
          bookingDeleteError.message,
        );
      }
    }

    // ------------------------------------------------------------
    // 8. Clear the unit assignment.
    //
    // Your current schema links tenant -> unit through tenants.unit_id.
    // Therefore we reset the unit status rather than relying on a
    // nonexistent units.tenant_id column.
    // ------------------------------------------------------------

    if (unitId) {
      const { error: unitError } = await admin
        .from("units")
        .update({
          status: "vacant",
        })
        .eq("id", unitId)
        .eq("property_id", propertyId);

      if (unitError) {
        console.warn(
          "Unit cleanup warning:",
          unitError.message,
        );
      }
    }

    // ------------------------------------------------------------
    // 9. Delete tenant profile.
    // ------------------------------------------------------------

    if (authUserId) {
      const { error: profileError } = await admin
        .from("profiles")
        .delete()
        .eq("id", authUserId);

      if (profileError) {
        console.warn(
          "Profile deletion warning:",
          profileError.message,
        );
      }
    }

    // ------------------------------------------------------------
    // 10. Delete tenant database record.
    // ------------------------------------------------------------

    const { error: tenantDeleteError } = await admin
      .from("tenants")
      .delete()
      .eq("id", tenantId);

    if (tenantDeleteError) {
      throw new Error(
        `Failed to delete tenant record: ${tenantDeleteError.message}`,
      );
    }

    // ------------------------------------------------------------
    // 11. Delete Supabase Auth account.
    //
    // conversation_participants.profile_id,
    // messages.sender_id and messages.receiver_id all reference
    // auth.users with ON DELETE CASCADE.
    //
    // Therefore deleting this Auth user removes their messaging
    // participant/message records automatically.
    // ------------------------------------------------------------

    if (authUserId) {
      const { error: authDeleteError } =
        await admin.auth.admin.deleteUser(authUserId);

      if (authDeleteError) {
        throw new Error(
          `Tenant database record was deleted, but Auth account deletion failed: ${authDeleteError.message}`,
        );
      }
    }

    // ------------------------------------------------------------
    // 12. Clean up conversations that no longer have participants.
    //
    // We deliberately do NOT delete conversations that still contain
    // another participant.
    // ------------------------------------------------------------

    const { data: conversations } = await admin
      .from("conversations")
      .select("id");

    if (Array.isArray(conversations)) {
      for (const conversation of conversations) {
        const conversationId = conversation.id?.toString();

        if (!conversationId) continue;

        const { count } = await admin
          .from("conversation_participants")
          .select("id", {
            count: "exact",
            head: true,
          })
          .eq("conversation_id", conversationId);

        if ((count ?? 0) === 0) {
          await admin
            .from("conversations")
            .delete()
            .eq("id", conversationId);
        }
      }
    }

    // ------------------------------------------------------------
    // 13. Return success.
    // ------------------------------------------------------------

    return new Response(
      JSON.stringify({
        success: true,
        message:
          "Tenant, tenant profile, Auth account, booking requests, unit assignment and tenant messaging access were permanently removed.",
        tenant_id: tenantId,
        auth_user_id: authUserId || null,
        property_id: propertyId,
        unit_id: unitId || null,
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
    console.error("delete-tenant-account error:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error
          ? error.message
          : "Failed to delete tenant account.",
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
