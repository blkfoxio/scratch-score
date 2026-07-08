// Shared Sign in with Apple helpers for Edge Functions.
//
// Requires these function secrets (set via `supabase secrets set …`, never shipped):
//   APPLE_TEAM_ID     — your Apple Developer Team ID
//   APPLE_CLIENT_ID   — the app bundle id (app.scratchscore)
//   APPLE_KEY_ID      — the Key ID of your Sign in with Apple .p8 AuthKey
//   APPLE_PRIVATE_KEY — the full contents of the .p8 file (BEGIN/END PRIVATE KEY included)

import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

/// Builds the short-lived ES256 client secret JWT Apple requires for token requests.
export async function appleClientSecret(): Promise<string> {
  const teamId = requireEnv("APPLE_TEAM_ID");
  const clientId = requireEnv("APPLE_CLIENT_ID");
  const keyId = requireEnv("APPLE_KEY_ID");
  const privateKeyPem = requireEnv("APPLE_PRIVATE_KEY");

  return await create(
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
}

/// Exchanges a one-time Apple authorization code for a long-lived refresh token.
/// Returns undefined if Apple doesn't return one.
export async function exchangeAuthCode(authorizationCode: string): Promise<string | undefined> {
  const clientId = requireEnv("APPLE_CLIENT_ID");
  const clientSecret = await appleClientSecret();

  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    grant_type: "authorization_code",
    code: authorizationCode,
  });

  const res = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!res.ok) throw new Error(`Apple token exchange HTTP ${res.status}: ${await res.text()}`);
  const json = await res.json();
  return json.refresh_token as string | undefined;
}

/// Revokes a previously-issued Apple refresh token (required on account deletion).
export async function revokeAppleToken(refreshToken: string): Promise<void> {
  const clientId = requireEnv("APPLE_CLIENT_ID");
  const clientSecret = await appleClientSecret();

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

function requireEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing function secret: ${name}`);
  return value;
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
