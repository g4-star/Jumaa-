import { corsHeaders } from "../_shared/cors.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const headers = {
  apikey: SUPABASE_SERVICE_ROLE_KEY,
  Authorization: `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
  "Content-Type": "application/json",
};

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
    value,
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error(
        "Supabase service credentials are not configured.",
      );
    }

    const body = await req.json();

    const landlordId =
      body?.landlord_id?.toString().trim() ?? "";

    const landlordEmail =
      body?.email?.toString().trim().toLowerCase() ?? "";

    if (!landlordId && !landlordEmail) {
      return jsonResponse(
        {
          success: false,
          error: "landlord_id or email is required.",
        },
        400,
      );
    }

    console.log(
      `Delete request: id=${landlordId}, email=${landlordEmail}`,
    );

    let landlordUuid = "";
    let landlordRecord: any = null;

    // ----------------------------------------------------------
    // 1. ALWAYS TRY EMAIL FIRST.
    //
    // Old local IDs such as ONL-1001 and ONL-1002 are not UUIDs.
    // The email is the reliable identifier for those accounts.
    // ----------------------------------------------------------

    if (landlordEmail) {
      const response = await fetch(
        `${SUPABASE_URL}/rest/v1/landlords?email=eq.${encodeURIComponent(
          landlordEmail,
        )}&select=id,email,full_name`,
        {
          method: "GET",
          headers,
        },
      );

      if (!response.ok) {
        throw new Error(
          `Could not search for landlord by email: ${
            await response.text()
          }`,
        );
      }

      const rows = await response.json();

      if (Array.isArray(rows) && rows.length > 0) {
        landlordRecord = rows[0];
        landlordUuid =
          landlordRecord.id?.toString().trim() ?? "";
      }
    }

    // ----------------------------------------------------------
    // 2. ONLY USE landlord_id IF IT IS ACTUALLY A UUID.
    //
    // This prevents ONL-1001 / ONL-1002 from ever reaching
    // the PostgreSQL UUID column.
    // ----------------------------------------------------------

    if (!landlordUuid && landlordId && isUuid(landlordId)) {
      const response = await fetch(
        `${SUPABASE_URL}/rest/v1/landlords?id=eq.${encodeURIComponent(
          landlordId,
        )}&select=id,email,full_name`,
        {
          method: "GET",
          headers,
        },
      );

      if (!response.ok) {
        throw new Error(
          `Could not search for landlord by UUID: ${
            await response.text()
          }`,
        );
      }

      const rows = await response.json();

      if (Array.isArray(rows) && rows.length > 0) {
        landlordRecord = rows[0];
        landlordUuid =
          landlordRecord.id?.toString().trim() ?? "";
      }
    }

    // ----------------------------------------------------------
    // 3. LANDLORD DOES NOT EXIST IN SUPABASE.
    //
    // This can happen with old local-only landlord accounts.
    // Tell Flutter that it is safe to remove the stale local
    // account.
    // ----------------------------------------------------------

    if (!landlordUuid) {
      console.log(
        `No Supabase landlord found for ${landlordEmail || landlordId}`,
      );

      return jsonResponse({
        success: true,
        already_deleted: true,
        local_only: true,
        message:
          "No Supabase landlord account was found. The local landlord record can be removed.",
      });
    }

    console.log(
      `Resolved REAL Supabase landlord UUID: ${landlordUuid}`,
    );

    // ----------------------------------------------------------
    // 4. REMOVE PROPERTY ASSIGNMENT.
    // ----------------------------------------------------------

    const propertyResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/properties?landlord_id=eq.${encodeURIComponent(
        landlordUuid,
      )}`,
      {
        method: "PATCH",
        headers: {
          ...headers,
          Prefer: "return=minimal",
        },
        body: JSON.stringify({
          landlord_id: null,
        }),
      },
    );

    if (!propertyResponse.ok) {
      throw new Error(
        `Could not remove landlord property assignment: ${
          await propertyResponse.text()
        }`,
      );
    }

    // ----------------------------------------------------------
    // 5. DELETE public.landlords.
    // ----------------------------------------------------------

    const landlordDeleteResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/landlords?id=eq.${encodeURIComponent(
        landlordUuid,
      )}`,
      {
        method: "DELETE",
        headers: {
          ...headers,
          Prefer: "return=minimal",
        },
      },
    );

    if (!landlordDeleteResponse.ok) {
      throw new Error(
        `Could not delete landlord record: ${
          await landlordDeleteResponse.text()
        }`,
      );
    }

    // ----------------------------------------------------------
    // 6. DELETE public.profiles.
    // ----------------------------------------------------------

    const profileDeleteResponse = await fetch(
      `${SUPABASE_URL}/rest/v1/profiles?id=eq.${encodeURIComponent(
        landlordUuid,
      )}`,
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

    // ----------------------------------------------------------
    // 7. DELETE Supabase Auth USER.
    // ----------------------------------------------------------

    const authDeleteResponse = await fetch(
      `${SUPABASE_URL}/auth/v1/admin/users/${encodeURIComponent(
        landlordUuid,
      )}`,
      {
        method: "DELETE",
        headers,
      },
    );

    if (!authDeleteResponse.ok) {
      const errorText = await authDeleteResponse.text();

      if (
        !errorText.toLowerCase().includes("not found") &&
        !errorText.toLowerCase().includes("user not found")
      ) {
        throw new Error(
          `Could not delete landlord Auth account: ${errorText}`,
        );
      }
    }

    console.log(
      `Successfully deleted landlord ${landlordUuid}`,
    );

    return jsonResponse({
      success: true,
      already_deleted: false,
      landlord_id: landlordUuid,
      email: landlordRecord?.email ?? landlordEmail,
      message: "Landlord account deleted successfully.",
    });
  } catch (error) {
    console.error(
      "delete-landlord-account error:",
      error,
    );

    return jsonResponse(
      {
        success: false,
        error:
          error instanceof Error
            ? error.message
            : "Failed to delete landlord account.",
      },
      500,
    );
  }
});
