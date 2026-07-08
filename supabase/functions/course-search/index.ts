// Supabase Edge Function: course-search
//
// Proxies golfcourseapi.com search so the API key stays server-side (never shipped in
// the app). Requires an authenticated Supabase user, then forwards the query with the
// key stored as a function secret and returns the provider's JSON verbatim.
//
// Required function secret (NEVER shipped in the app):
//   supabase secrets set GOLF_COURSE_API_KEY=your-key
// (SUPABASE_URL and SUPABASE_ANON_KEY are auto-injected by the platform.)
//
// Deploy: supabase functions deploy course-search

import { createClient } from "jsr:@supabase/supabase-js@2";

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
    // Require an authenticated user (not just the anon key).
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Not authenticated" }, 401);

    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user } } = await userClient.auth.getUser();
    if (!user) return json({ error: "Not authenticated" }, 401);

    const { q } = await req.json().catch(() => ({ q: "" }));
    const query = (q ?? "").toString().trim();
    if (!query) return json({ courses: [] });

    const apiKey = Deno.env.get("GOLF_COURSE_API_KEY");
    if (!apiKey) return json({ error: "Server missing GOLF_COURSE_API_KEY" }, 500);

    const url = `https://api.golfcourseapi.com/v1/search?search_query=${encodeURIComponent(query)}`;
    const res = await fetch(url, { headers: { Authorization: `Key ${apiKey}` } });
    const body = await res.text();

    // Pass the provider's response (and status) straight through to the client.
    return new Response(body, {
      status: res.status,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return json({ error: String(e) }, 500);
  }
});
