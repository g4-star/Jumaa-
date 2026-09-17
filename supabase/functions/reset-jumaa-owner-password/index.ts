import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

async function sha256(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const hash = await crypto.subtle.digest("SHA-256", data);

  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function generateCode(): string {
  const array = new Uint32Array(1);
  crypto.getRandomValues(array);

  return String(10000 + (array[0] % 90000));
}

function generateResetToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);

  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    const brevoApiKey = Deno.env.get("BREVO_API_KEY");
    const emailFrom =
      Deno.env.get("EMAIL_FROM") ?? "JUMAA <your-verified-email@example.com>";

    if (!supabaseUrl || !serviceRoleKey) {
      return jsonResponse(
        { error: "Supabase server configuration is incomplete." },
        500,
      );
    }

    if (!brevoApiKey) {
      return jsonResponse(
        { error: "Email service is not configured." },
        500,
      );
    }

    const supabaseAdmin = createClient(
      supabaseUrl,
      serviceRoleKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    );

    const body = await req.json();

    const action = String(body.action ?? "").trim();
    const email = String(body.email ?? "").trim().toLowerCase();

    if (action === "request_code" || action === "verify_code") {
      if (!email || !email.includes("@")) {
        return jsonResponse(
          { error: "A valid email address is required." },
          400,
        );
      }
    }

    // ==========================================================
    // REQUEST RESET CODE
    // ==========================================================

    if (action === "request_code") {
      /*
       * Always return the same public response whether the
       * account exists or not.
       *
       * This prevents email/account enumeration.
       */

      const { data: usersData, error: usersError } =
        await supabaseAdmin.auth.admin.listUsers({
          page: 1,
          perPage: 1000,
        });

      if (usersError) {
        console.error("Could not list users:", usersError);

        return jsonResponse(
          {
            success: true,
            message:
              "If an account exists for this email, a verification code has been sent.",
          },
        );
      }

      const user = usersData.users.find(
        (u) => u.email?.toLowerCase() === email,
      );

      if (user) {
        const code = generateCode();
        const codeHash = await sha256(code);

        // Invalidate previous active codes.
        await supabaseAdmin
          .from("password_reset_codes")
          .update({ used: true })
          .eq("email", email)
          .eq("used", false);

        const expiresAt = new Date(
          Date.now() + 10 * 60 * 1000,
        ).toISOString();

        const { error: insertError } = await supabaseAdmin
          .from("password_reset_codes")
          .insert({
            email,
            code_hash: codeHash,
            expires_at: expiresAt,
            used: false,
            attempts: 0,
          });

        if (insertError) {
          console.error("Could not store reset code:", insertError);

          return jsonResponse(
            {
              error: "Could not create password reset request.",
            },
            500,
          );
        }

        const firstName =
          user.user_metadata?.full_name ??
          user.user_metadata?.name ??
          "JUMAA User";

        const emailResponse = await fetch(
          "https://api.brevo.com/v3/smtp/email",
          {
            method: "POST",
            headers: {
              "api-key": brevoApiKey,
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: JSON.stringify({
              sender: {
                name: "JUMAA",
                email: emailFrom
                  .replace(/^.*<|>.*$/g, "")
                  .trim(),
              },
              to: [
                {
                  email,
                },
              ],
              subject: "JUMAA Password Reset Code",
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
<body style="font-family:Arial,sans-serif;background:#f5f7f6;padding:24px;">
  <div style="max-width:600px;margin:auto;background:#ffffff;padding:30px;border-radius:14px;">
    <h2 style="color:#0B3D2E;">JUMAA Password Reset</h2>

    <p>Hello <strong>${String(firstName)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")}</strong>,</p>

    <p>
      We received a request to reset your JUMAA password.
    </p>

    <p>Your verification code is:</p>

    <div style="background:#eef5f1;padding:22px;border-radius:10px;text-align:center;margin:25px 0;">
      <div style="font-size:34px;letter-spacing:8px;font-weight:bold;color:#0B3D2E;">
        ${code}
      </div>
    </div>

    <p>
      This code expires in <strong>10 minutes</strong>.
    </p>

    <p>
      Do not share this code with anyone.
    </p>

    <p>
      If you did not request a password reset, you can safely ignore this email.
    </p>

    <p style="margin-top:30px;">
      Regards,<br>
      <strong>JUMAA</strong>
    </p>
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
          const result = await emailResponse.text();
          console.error("Brevo error:", result);

          return jsonResponse(
            {
              error: "Could not send the verification email.",
            },
            500,
          );
        }
      }

      return jsonResponse({
        success: true,
        message:
          "If an account exists for this email, a verification code has been sent.",
      });
    }

    // ==========================================================
    // VERIFY CODE
    // ==========================================================

    if (action === "verify_code") {
      const code = String(body.code ?? "").trim();

      if (!/^\d{5}$/.test(code)) {
        return jsonResponse(
          { error: "Invalid verification code." },
          400,
        );
      }

      const { data: resetRecord, error: lookupError } =
        await supabaseAdmin
          .from("password_reset_codes")
          .select("*")
          .eq("email", email)
          .eq("used", false)
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle();

      if (lookupError || !resetRecord) {
        return jsonResponse(
          { error: "Invalid or expired verification code." },
          400,
        );
      }

      if (new Date(resetRecord.expires_at).getTime() < Date.now()) {
        return jsonResponse(
          { error: "This verification code has expired." },
          400,
        );
      }

      if (resetRecord.attempts >= 5) {
        return jsonResponse(
          {
            error:
              "Too many incorrect attempts. Please request a new code.",
          },
          429,
        );
      }

      const submittedHash = await sha256(code);

      if (submittedHash !== resetRecord.code_hash) {
        await supabaseAdmin
          .from("password_reset_codes")
          .update({
            attempts: resetRecord.attempts + 1,
          })
          .eq("id", resetRecord.id);

        return jsonResponse(
          { error: "Invalid verification code." },
          400,
        );
      }

      const resetToken = generateResetToken();
      const resetTokenHash = await sha256(resetToken);

      await supabaseAdmin
        .from("password_reset_codes")
        .update({
          code_hash: resetTokenHash,
        })
        .eq("id", resetRecord.id);

      return jsonResponse({
        success: true,
        reset_token: resetToken,
      });
    }

    // ==========================================================
    // RESET PASSWORD
    // ==========================================================

    if (action === "reset_password") {
      const resetToken = String(body.reset_token ?? "").trim();
      const newPassword = String(body.new_password ?? "");

      if (!resetToken) {
        return jsonResponse(
          { error: "Reset verification is required." },
          400,
        );
      }

      if (newPassword.length < 8) {
        return jsonResponse(
          { error: "Password must be at least 8 characters." },
          400,
        );
      }

      const tokenHash = await sha256(resetToken);

      const { data: resetRecord, error: lookupError } =
        await supabaseAdmin
          .from("password_reset_codes")
          .select("*")
          .eq("code_hash", tokenHash)
          .eq("used", false)
          .order("created_at", { ascending: false })
          .limit(1)
          .maybeSingle();

      if (lookupError || !resetRecord) {
        return jsonResponse(
          { error: "Invalid or expired password reset session." },
          400,
        );
      }

      if (new Date(resetRecord.expires_at).getTime() < Date.now()) {
        return jsonResponse(
          { error: "Password reset session has expired." },
          400,
        );
      }

      const emailForReset = resetRecord.email;

      const { data: usersData, error: usersError } =
        await supabaseAdmin.auth.admin.listUsers({
          page: 1,
          perPage: 1000,
        });

      if (usersError) {
        console.error("Could not find Auth user:", usersError);

        return jsonResponse(
          { error: "Could not reset password." },
          500,
        );
      }

      const user = usersData.users.find(
        (u) => u.email?.toLowerCase() === emailForReset,
      );

      if (!user) {
        return jsonResponse(
          { error: "Could not find the JUMAA account." },
          400,
        );
      }

      const { error: updateError } =
        await supabaseAdmin.auth.admin.updateUserById(
          user.id,
          {
            password: newPassword,
          },
        );

      if (updateError) {
        console.error("Password update error:", updateError);

        return jsonResponse(
          { error: updateError.message },
          400,
        );
      }

      // Make the reset token unusable immediately.
      await supabaseAdmin
        .from("password_reset_codes")
        .update({
          used: true,
        })
        .eq("id", resetRecord.id);

      return jsonResponse({
        success: true,
        message: "Password reset successfully.",
      });
    }

    return jsonResponse(
      { error: "Invalid reset action." },
      400,
    );
  } catch (error) {
    console.error("PASSWORD RESET ERROR:", error);

    return jsonResponse(
      {
        error:
          error instanceof Error
            ? error.message
            : String(error),
      },
      500,
    );
  }
});
