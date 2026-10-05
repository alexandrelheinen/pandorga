/**
 * Studio API stub shipped with the gem (PLT-0.2 Option A).
 * Real handlers are copied from the website extraction in later phases.
 * GITHUB_REPO is required — no default owner.
 */

function corsHeaders(request, env) {
  const origin = request.headers.get("Origin") || "";
  const allowed = String(env.STUDIO_ALLOWED_ORIGINS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  const local =
    origin.includes("localhost") || origin.includes("127.0.0.1");
  const ok = !origin || local || allowed.includes(origin);
  return {
    "Access-Control-Allow-Origin": ok ? origin || "*" : "null",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
    "Access-Control-Allow-Methods": "GET, PUT, POST, OPTIONS",
  };
}

export async function onRequest(context) {
  const { request, env } = context;
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(request, env) });
  }
  if (!env.GITHUB_REPO) {
    return new Response(
      JSON.stringify({
        error: "misconfigured",
        message: "GITHUB_REPO is required",
      }),
      {
        status: 500,
        headers: {
          "Content-Type": "application/json",
          ...corsHeaders(request, env),
        },
      }
    );
  }
  return new Response(
    JSON.stringify({
      ok: true,
      message: "pandorga studio stub — full API lands with extraction",
      repo: env.GITHUB_REPO,
    }),
    {
      status: 200,
      headers: {
        "Content-Type": "application/json",
        ...corsHeaders(request, env),
      },
    }
  );
}
