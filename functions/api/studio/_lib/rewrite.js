/**
 * Studio rewrite orchestration (Correct / Refine).
 * Spec: docs/features/studio-proof.md §7.
 */

import { flattenBlockPatches, splitIntoBlocks } from "./blocks.js";
import { buildGeminiRequest } from "./prompts.js";
import { callGemini } from "./gemini.js";
import { loadGuidelinesPack } from "./guidelines.js";
import { clientAddress, takeToken } from "./rate-limit.js";
import { sanitizePatches } from "./sanitize.js";

const MAX_TEXT = 100_000;
const MAX_CONTEXT = 2_000;
const REWRITE_RATE = new Map();
const REWRITE_WINDOW_MS = 60_000;
const REWRITE_MAX = 5;
/** Allow more local patches when refining a long multi-block selection. */
const REFINE_MAX_PATCHES = 60;

/**
 * @param {Request} request
 * @param {string} userId
 * @returns {{ allowed: boolean, retryAfterSec: number }}
 */
export function rewriteRateLimit(request, userId) {
  return takeToken(
    REWRITE_RATE,
    `rewrite:${userId}:${clientAddress(request)}`,
    Date.now(),
    { windowMs: REWRITE_WINDOW_MS, max: REWRITE_MAX }
  );
}

/**
 * @param {object} env
 * @param {object} body — parsed JSON body
 */
export async function runRewrite(env, body) {
  const mode = String(body?.mode || "").toLowerCase();
  if (mode !== "correct" && mode !== "refine") {
    const err = new Error("invalid_body");
    err.code = "invalid_body";
    err.status = 400;
    throw err;
  }

  const language = String(body?.language || "").trim();
  if (!language) {
    const err = new Error("language_required");
    err.code = "language_required";
    err.status = 400;
    throw err;
  }

  const text = String(body?.text ?? "");
  if (!text) {
    const err = new Error("invalid_body");
    err.code = "invalid_body";
    err.status = 400;
    throw err;
  }
  if (text.length > MAX_TEXT) {
    const err = new Error("invalid_body");
    err.code = "invalid_body";
    err.status = 400;
    throw err;
  }

  const path = String(body?.path || "");
  // Spec: when selection is present, `text` is already the slice; offsets are
  // relative to that slice. SPA applies against the same `text` it sent.
  const workText = text;

  let context = null;
  if (mode === "refine" && body?.context && typeof body.context === "object") {
    context = {
      before: String(body.context.before || "").slice(-MAX_CONTEXT),
      after: String(body.context.after || "").slice(0, MAX_CONTEXT),
    };
  }

  let guidelinesVersion = null;
  let guidelinesBody = "";
  if (mode === "refine") {
    const pack = await loadGuidelinesPack(env);
    guidelinesBody = pack.body_markdown;
    guidelinesVersion = pack.body_sha256;
  }

  const blocks = mode === "refine" ? splitIntoBlocks(workText) : null;

  const geminiBody = buildGeminiRequest({
    mode,
    language,
    path,
    text: workText,
    context,
    guidelinesBody,
    blocks,
  });

  let gemini;
  try {
    gemini = await callGemini(env, geminiBody);
  } catch (err) {
    if (err.code === "gemini_unconfigured") {
      err.status = 503;
      err.code = "gemini_upstream";
    } else if (!err.status) {
      err.status = 502;
      err.code = err.code || "gemini_upstream";
    }
    throw err;
  }

  const rawPatches =
    mode === "refine"
      ? flattenBlockPatches(blocks, gemini.patches)
      : gemini.patches;

  const { patches, stats } = sanitizePatches({
    mode,
    text: workText,
    patches: rawPatches,
    maxPatches: mode === "refine" ? REFINE_MAX_PATCHES : 40,
  });

  return {
    mode,
    guidelines_version: guidelinesVersion,
    model: gemini.model,
    patches,
    stats,
  };
}
