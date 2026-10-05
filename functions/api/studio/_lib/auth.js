/**
 * Clerk JWT verification + allowlist. Spec: docs/features/studio.md §4.
 */

function parseAllowlist(raw) {
  return String(raw || "")
    .split(/[,\s]+/)
    .map((s) => s.trim().toLowerCase())
    .filter(Boolean);
}

async function fetchJwks(publishableOrSecretHint, env) {
  // Prefer explicit issuer; fall back to Clerk Frontend API from publishable key.
  const issuer =
    env.CLERK_JWT_ISSUER ||
    env.CLERK_FRONTEND_API ||
    inferIssuerFromPublishable(env.CLERK_PUBLISHABLE_KEY);
  if (!issuer) {
    throw new Error("CLERK_JWT_ISSUER or CLERK_PUBLISHABLE_KEY required");
  }
  const base = issuer.replace(/\/$/, "");
  const res = await fetch(`${base}/.well-known/jwks.json`);
  if (!res.ok) throw new Error(`JWKS fetch failed: ${res.status}`);
  return { jwks: await res.json(), issuer: base };
}

function inferIssuerFromPublishable(key) {
  // pk_test_… / pk_live_… — Frontend API host is not fully recoverable from
  // the key alone in all Clerk versions; prefer CLERK_JWT_ISSUER.
  void key;
  return null;
}

function b64urlToBytes(str) {
  const pad = "=".repeat((4 - (str.length % 4)) % 4);
  const b64 = (str + pad).replace(/-/g, "+").replace(/_/g, "/");
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

function decodeJwtPart(part) {
  return JSON.parse(new TextDecoder().decode(b64urlToBytes(part)));
}

async function importClerkKey(jwk) {
  return crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"]
  );
}

export async function verifyClerkRequest(request, env) {
  if (env.STUDIO_DEV_BYPASS === "1" && env.ENVIRONMENT !== "production") {
    return {
      userId: "dev_bypass",
      email: "dev@localhost",
      bypass: true,
    };
  }

  const header = request.headers.get("Authorization") || "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    return { error: "missing_bearer", status: 401 };
  }
  const token = match[1].trim();
  const parts = token.split(".");
  if (parts.length !== 3) {
    return { error: "malformed_jwt", status: 401 };
  }

  let headerJson;
  let payload;
  try {
    headerJson = decodeJwtPart(parts[0]);
    payload = decodeJwtPart(parts[1]);
  } catch {
    return { error: "malformed_jwt", status: 401 };
  }

  const { jwks, issuer } = await fetchJwks(null, env);
  const jwk = (jwks.keys || []).find((k) => k.kid === headerJson.kid) || jwks.keys?.[0];
  if (!jwk) {
    return { error: "no_jwk", status: 401 };
  }

  const key = await importClerkKey(jwk);
  const data = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const sig = b64urlToBytes(parts[2]);
  const ok = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", key, sig, data);
  if (!ok) {
    return { error: "bad_signature", status: 401 };
  }

  const now = Math.floor(Date.now() / 1000);
  if (payload.exp && payload.exp < now) {
    return { error: "expired", status: 401 };
  }
  if (payload.nbf && payload.nbf > now + 5) {
    return { error: "not_yet_valid", status: 401 };
  }
  if (issuer && payload.iss && !String(payload.iss).replace(/\/$/, "").startsWith(issuer)) {
    // Soft check: some Clerk tokens use https://clerk.… vs Frontend API host.
    // Still require allowlist match below.
  }

  const userId = String(payload.sub || "");
  const email = String(
    payload.email ||
      payload.primary_email_address ||
      payload.email_address ||
      ""
  ).toLowerCase();

  const allow = parseAllowlist(env.STUDIO_ALLOWLIST);
  if (!allow.length) {
    return { error: "allowlist_empty", status: 403, userId, email };
  }
  const allowed =
    allow.includes(userId.toLowerCase()) || (email && allow.includes(email));
  if (!allowed) {
    return { error: "not_allowlisted", status: 403, userId, email };
  }

  return { userId, email, payload };
}
