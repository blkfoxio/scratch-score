// Supabase Edge Function: apple-register-token
//
// Called by the client right after a native Sign in with Apple. Exchanges the one-time
// Apple `authorization_code` for a refresh token and stores it in the user's app_metadata
// so `delete-account` can later revoke it (App Store Guideline 5.1.1(v)).
//
// Requires the same APPLE_* secrets as _shared/apple.ts. Deploy:
//   supabase functions deploy apple-register-token

import { createClient } from "jsr:@supabase/supabase-js@2";
import { exchangeAuthCode } from "../_shared/apple.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Not authenticated" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const userClient = createClient(supabaseUrl, Deno.env.get("SUPABASE_ANON_KEY")!, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "Not authenticated" }, 401);

    const { authorization_code } = await req.json().catch(() => ({}));
    if (!authorization_code) return json({ error: "Missing authorization_code" }, 400);

    const refreshToken = await exchangeAuthCode(String(authorization_code));
    if (!refreshToken) return json({ success: true, stored: false });

    // Store on app_metadata (server-only, auto-removed when the user is deleted).
    const admin = createClient(supabaseUrl, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const existing = (user.app_metadata ?? {}) as Record<string, unknown>;
    const { error } = await admin.auth.admin.updateUserById(user.id, {
      app_metadata: { ...existing, apple_refresh_token: refreshToken },
    });
    if (error) return json({ error: error.message }, 500);

    return json({ success: true, stored: true });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
