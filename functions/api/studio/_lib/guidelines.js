/**
 * Load guidelines/studio-proof/pack.json from R2 (S3-compatible).
 * Spec: docs/features/studio-proof.md §6 (AC-PRF-08).
 */

const cache = {
  bodySha: null,
  pack: null,
  loadedAt: 0,
};
const TTL_MS = 60 * 60 * 1000;

/**
 * Minimal AWS SigV4 for S3 GetObject (R2).
 * @param {object} env
 * @param {string} key — object key without leading slash
 */
async function signedGet(env, key) {
  const accessKey = String(env.R2_ACCESS_KEY_ID || "").trim();
  const secretKey = String(env.R2_SECRET_ACCESS_KEY || "").trim();
  const endpoint = String(env.R2_ENDPOINT || "").replace(/\/$/, "");
  const bucket = String(env.R2_BUCKET || "").trim();
  if (!accessKey || !secretKey || !endpoint || !bucket) {
    const err = new Error("r2_unconfigured");
    err.code = "guidelines_unavailable";
    throw err;
  }

  const url = new URL(endpoint);
  const host = url.host;
  const amzDate = new Date().toISOString().replace(/[:-]|\.\d{3}/g, "");
  const dateStamp = amzDate.slice(0, 8);
  const region = String(env.R2_REGION || "auto");
  const service = "s3";
  const canonicalUri = `/${bucket}/${key.split("/").map(encodeURIComponent).join("/")}`;
  const payloadHash = await sha256Hex("");
  const canonicalHeaders = `host:${host}\nx-amz-content-sha256:${payloadHash}\nx-amz-date:${amzDate}\n`;
  const signedHeaders = "host;x-amz-content-sha256;x-amz-date";
  const canonicalRequest = [
    "GET",
    canonicalUri,
    "",
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join("\n");
  const credentialScope = `${dateStamp}/${region}/${service}/aws4_request`;
  const stringToSign = [
    "AWS4-HMAC-SHA256",
    amzDate,
    credentialScope,
    await sha256Hex(canonicalRequest),
  ].join("\n");
  const signingKey = await getSignatureKey(secretKey, dateStamp, region, service);
  const signature = await hmacHex(signingKey, stringToSign);
  const authorization = `AWS4-HMAC-SHA256 Credential=${accessKey}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  const res = await fetch(`${endpoint}${canonicalUri}`, {
    method: "GET",
    headers: {
      Host: host,
      "x-amz-date": amzDate,
      "x-amz-content-sha256": payloadHash,
      Authorization: authorization,
    },
  });
  if (res.status === 404) {
    const err = new Error("pack_missing");
    err.code = "guidelines_unavailable";
    throw err;
  }
  if (!res.ok) {
    const err = new Error(`r2_http_${res.status}`);
    err.code = "guidelines_unavailable";
    throw err;
  }
  return res.json();
}

async function sha256Hex(message) {
  const data = new TextEncoder().encode(message);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(hash)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function hmac(key, message) {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    typeof key === "string" ? new TextEncoder().encode(key) : key,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", cryptoKey, new TextEncoder().encode(message));
  return new Uint8Array(sig);
}

async function hmacHex(key, message) {
  const sig = await hmac(key, message);
  return [...sig].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function getSignatureKey(secretKey, dateStamp, region, service) {
  const kDate = await hmac(`AWS4${secretKey}`, dateStamp);
  const kRegion = await hmac(kDate, region);
  const kService = await hmac(kRegion, service);
  return hmac(kService, "aws4_request");
}

/**
 * @param {object} env
 * @returns {Promise<{ body_markdown: string, body_sha256: string }>}
 */
export async function loadGuidelinesPack(env) {
  // Test / local override without R2.
  if (env.GUIDELINES_PACK_JSON) {
    const pack = JSON.parse(String(env.GUIDELINES_PACK_JSON));
    return pack;
  }

  const now = Date.now();
  if (cache.pack && now - cache.loadedAt < TTL_MS) {
    return cache.pack;
  }

  const pack = await signedGet(env, "guidelines/studio-proof/pack.json");
  if (!pack?.body_markdown || !pack?.body_sha256) {
    const err = new Error("pack_invalid");
    err.code = "guidelines_unavailable";
    throw err;
  }
  cache.pack = pack;
  cache.bodySha = pack.body_sha256;
  cache.loadedAt = now;
  return pack;
}

/** @visibleForTesting */
export function clearGuidelinesCache() {
  cache.pack = null;
  cache.bodySha = null;
  cache.loadedAt = 0;
}
