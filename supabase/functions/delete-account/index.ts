// Supabase Edge Function: delete-account
//
// Invoked by the signed-in client (`supabase.functions.invoke("delete-account")`).
// The user's JWT is attached automatically. This function:
//   1. Identifies the caller from their JWT.
//   2. Revokes their Sign in with Apple token (App Store Guideline 5.1.1(v)) if present.
//   3. Deletes the auth user with the service-role key, which cascades every app row
//      via the `on delete cascade` foreign keys in 0001_init.sql.
//
// Required function secrets (set via `supabase secrets set ...`, NEVER shipped in the app):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY  (auto-populated by Supabase)
//   APPLE_TEAM_ID, APPLE_CLIENT_ID (app bundle id), APPLE_KEY_ID, APPLE_PRIVATE_KEY (.p8 contents)
//
// Deploy: supabase functions deploy delete-account

import { createClient } from "jsr:@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

Deno.serve(async (req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing Authorization header" }, 401, corsHeaders);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Identify the caller from their JWT (user-scoped client).
    const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await userClient.auth.getUser();
    if (userErr || !userData.user) {
      return json({ error: "Invalid session" }, 401, corsHeaders);
    }
    const user = userData.user;

    // Admin client (service role) for privileged operations.
    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // 1) Revoke Apple token if the user signed in with Apple and we stored a refresh token.
    try {
      const appleIdentity = user.identities?.find((i) => i.provider === "apple");
      const appleRefreshToken =
        (user.app_metadata as Record<string, unknown>)?.apple_refresh_token as string | undefined;
      if (appleIdentity && appleRefreshToken) {
        await revokeAppleToken(appleRefreshToken);
      }
    } catch (e) {
      // Non-fatal: log and continue with account deletion.
      console.error("Apple token revoke failed:", e);
    }

    // 2) Delete the auth user — cascades all app data through FK constraints.
    const { error: deleteErr } = await admin.auth.admin.deleteUser(user.id);
    if (deleteErr) {
      return json({ error: `Delete failed: ${deleteErr.message}` }, 500, corsHeaders);
    }

    return json({ success: true }, 200, corsHeaders);
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500, corsHeaders);
  }
});

function json(body: unknown, status: number, headers: Record<string, string>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}

/// Builds the Apple client secret (a short-lived ES256 JWT signed with the .p8 key)
/// and calls Apple's token revocation endpoint.
async function revokeAppleToken(refreshToken: string) {
  const teamId = Deno.env.get("APPLE_TEAM_ID")!;
  const clientId = Deno.env.get("APPLE_CLIENT_ID")!;
  const keyId = Deno.env.get("APPLE_KEY_ID")!;
  const privateKeyPem = Deno.env.get("APPLE_PRIVATE_KEY")!;

  const clientSecret = await create(
    { alg: "ES256", kid: keyId, typ: "JWT" },
    {
      iss: teamId,
      iat: getNumericDate(0),
      exp: getNumericDate(60 * 5),
      aud: "https://appleid.apple.com",
      sub: clientId,
    },
    await importApplePrivateKey(privateKeyPem),
  );

  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    token: refreshToken,
    token_type_hint: "refresh_token",
  });

  const res = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!res.ok) throw new Error(`Apple revoke HTTP ${res.status}: ${await res.text()}`);
}

async function importApplePrivateKey(pem: string): Promise<CryptoKey> {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const der = Uint8Array.from(atob(cleaned), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
}
