import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

    const body = await req.json();

    const tenantId = body?.tenant_id?.toString().trim() ?? "";
    const tenantEmail = body?.email?.toString().trim().toLowerCase() ?? "";

    if (!tenantId && !tenantEmail) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "tenant_id or email is required.",
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

    const headers = {
      apikey: SUPABASE_SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
    };

    // ------------------------------------------------------------
    // 1. Find the tenant record.
    // ------------------------------------------------------------

    let tenantQuery = `${SUPABASE_URL}/rest/v1/tenants?select=id,property_id,unit_id,full_name,email`;

    if (tenantId) {
      tenantQuery += `&id=eq.${encodeURIComponent(tenantId)}`;
    } else {
      tenantQuery += `&email=eq.${encodeURIComponent(tenantEmail)}`;
    }

    const tenantResponse = await fetch(tenantQuery, {
      method: "GET",
      headers,
    });

    if (!tenantResponse.ok) {
      throw new Error(
        `Failed to find tenant: ${await tenantResponse.text()}`,
      );
    }

    const tenantRows = await tenantResponse.json();

    if (!Array.isArray(tenantRows) || tenantRows.length === 0) {
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

    const tenant = tenantRows[0];

    const realTenantId = tenant.id?.toString() ?? "";
    const email = (tenant.email ?? tenantEmail).toString().trim().toLowerCase();

    // ------------------------------------------------------------
    // 2. Find the Auth/profile UUID using the tenant email.
    // ------------------------------------------------------------

    let authUserId = "";

    if (email) {
      const profileResponse = await fetch(
        `${SUPABASE_URL}/rest/v1/profiles?email=eq.${encodeURIComponent(email)}&role=eq.tenant&select=id,email,role`,
        {
          method: "GET",
          headers,
        },
      );

      if (!profileResponse.ok) {
        throw new Error(
          `Failed to find tenant profile: ${await profileResponse.text()}`,
        );
      }

      const profiles = await profileResponse.json();

      if (Array.isArray(profiles) && profiles.length > 0) {
        authUserId = profiles[0]?.id?.toString() ?? "";
      }
    }

    // ------------------------------------------------------------
    // 3. Remove tenant from any assigned unit.
    //
    // This is intentionally attempted only if the units table
    // actually has a tenant_id relationship.
    // ------------------------------------------------------------

    if (realTenantId) {
      const unitClearResponse = await fetch(
        `${SUPABASE_URL}/rest/v1/units?tenant_id=eq.${encodeURIComponent(realTenantId)}`,
        {
          method: "PATCH",
          headers: {
            ...headers,
            Prefer: "return=minimal",
          },
          body: JSON.stringify({
            tenant_id: null,
          }),
        },
      );

      if (!unitClearResponse.ok) {
        console.warn(
          "Could not clear unit tenant assignment:",
          await unitClearResponse.text(),
        );
      }
    }

    // ------------------------------------------------------------
    // 4. Delete tenant profile.
    // ------------------------------------------------------------

    if (authUserId) {
      const profileDeleteResponse = await fetch(
        `${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(authUserId)}`,
        {
          method: "DELETE",
          headers: {
            ...headers,
            Prefer: "return=minimal",
          },
        },
      );

      if (!profileDeleteResponse.ok) {
        console.warn(
          "Profile deletion warning:",
          await profileDeleteResponse.text(),
        );
      }
    }

    // ------------------------------------------------------------
    // 5. Delete Supabase Auth account.
    // ------------------------------------------------------------

    if (authUserId) {
      const authDeleteResponse = await fetch(
        `${SUPABASE_URL}/auth/v1/admin/users/${encodeURIComponent(authUserId)}`,
        {
          method: "DELETE",
          headers,
        },
      );

      if (!authDeleteResponse.ok) {
        throw new Error(
          `Tenant profile was found, but Auth account could not be deleted: ${await authDeleteResponse.text()}`,
        );
      }
    }

    // ------------------------------------------------------------
    // 6. Delete the actual tenant database record.
    //
    // THIS is what makes the tenant disappear from the owner's
    // tenant list because _loadTenants() reads this table.
    // ------------------------------------------------------------

    const tenantDeleteResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/tenants?id=eq.${encodeURIComponent(realTenantId)}`,
      {
        method: "DELETE",
        headers: {
          ...headers,
          Prefer: "return=minimal",
        },
      },
    );

    if (!tenantDeleteResponse.ok) {
      throw new Error(
        `Failed to delete tenant record: ${await tenantDeleteResponse.text()}`,
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: "Tenant account and tenant record deleted successfully.",
        tenant_id: realTenantId,
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
