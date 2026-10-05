/**
 * Gemini generateContent client (Google AI Studio / Generative Language API).
 * Spec: docs/features/studio-proof.md §5.
 */

/**
 * @param {object} env
 * @param {object} body — generateContent request payload
 * @returns {Promise<{ patches: unknown[], model: string, rawText: string }>}
 */
export async function callGemini(env, body) {
  const key = String(env.GEMINI_API_KEY || "").trim();
  if (!key) {
    const err = new Error("gemini_unconfigured");
    err.code = "gemini_unconfigured";
    throw err;
  }
  const model = String(env.GEMINI_MODEL || "gemini-2.5-flash").trim();
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(key)}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const raw = await res.text();
  if (!res.ok) {
    const err = new Error(`gemini_http_${res.status}`);
    err.code = "gemini_upstream";
    err.status = res.status;
    err.detail = raw.slice(0, 400);
    throw err;
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    const err = new Error("gemini_bad_json");
    err.code = "gemini_upstream";
    throw err;
  }

  const text =
    parsed?.candidates?.[0]?.content?.parts?.map((p) => p.text || "").join("") ||
    "";
  let payload;
  try {
    payload = JSON.parse(text);
  } catch {
    const err = new Error("gemini_schema_json");
    err.code = "gemini_upstream";
    err.detail = text.slice(0, 400);
    throw err;
  }

  return {
    patches: Array.isArray(payload.patches) ? payload.patches : [],
    model,
    rawText: text,
  };
}
