/**
 * Patch sanitizer for Studio Correct / Refine.
 * Spec: docs/features/studio-proof.md §3, §8 (AC-PRF-05–07).
 */

import { locateUnique } from "./blocks.js";

export const CORRECT_CATEGORIES = new Set([
  "spelling",
  "typo",
  "grammar",
  "punctuation",
  "idiom",
]);

export const REFINE_CATEGORIES = new Set([
  "spelling",
  "typo",
  "grammar",
  "punctuation",
  "idiom",
  "clarity",
  "flow",
  "prose",
]);

/** Any Liquid tag — include, cite, etc. */
const LIQUID_RE = /\{%[\s\S]*?%\}/g;
const FENCE_RE = /```[\s\S]*?```/g;
const INLINE_CODE_RE = /`[^`\n]+`/g;

/** @param {string} text */
export function protectedRanges(text) {
  const ranges = [];
  const pushAll = (re) => {
    re.lastIndex = 0;
    let m;
    while ((m = re.exec(text)) !== null) {
      ranges.push({ start: m.index, end: m.index + m[0].length });
    }
  };
  pushAll(LIQUID_RE);
  pushAll(FENCE_RE);
  pushAll(INLINE_CODE_RE);
  return ranges;
}

function overlapsProtected(start, end, ranges) {
  return ranges.some((r) => start < r.end && end > r.start);
}

/**
 * @param {object} opts
 * @param {"correct"|"refine"} opts.mode
 * @param {string} opts.text
 * @param {unknown[]} opts.patches
 * @param {number} [opts.maxPatches]
 * @param {number} [opts.maxReplacement]
 * @returns {{ patches: object[], stats: { proposed: number, kept: number, dropped: number } }}
 */
export function sanitizePatches({
  mode,
  text,
  patches,
  maxPatches = 40,
  maxReplacement = mode === "refine" ? 500 : 200,
}) {
  const allowed = mode === "refine" ? REFINE_CATEGORIES : CORRECT_CATEGORIES;
  const protected_ = protectedRanges(text || "");
  const src = typeof text === "string" ? text : "";
  const list = Array.isArray(patches) ? patches : [];
  const out = [];
  const seen = [];

  for (const raw of list) {
    if (!raw || typeof raw !== "object") continue;

    const original = String(raw.original ?? "");
    const replacement = String(raw.replacement ?? "");
    const category = String(raw.category || "").toLowerCase();
    const reason = String(raw.reason || "").slice(0, 160);

    if (!allowed.has(category)) continue;
    if (!original || replacement === original) continue;
    if (replacement.length > maxReplacement) continue;
    if (replacement.length === 0 && original.length > 8) continue;

    let start = Number(raw.start);
    let end = Number(raw.end);
    if (
      !Number.isInteger(start) ||
      !Number.isInteger(end) ||
      start < 0 ||
      end < start ||
      end > src.length ||
      src.slice(start, end) !== original
    ) {
      const hint = Number.isInteger(start) ? start : 0;
      const loc = locateUnique(src, original, hint);
      if (!loc) continue;
      start = loc.start;
      end = loc.end;
    }

    if (overlapsProtected(start, end, protected_)) continue;
    if (seen.some((r) => start < r.end && end > r.start)) continue;

    seen.push({ start, end });
    out.push({
      start,
      end,
      original,
      replacement,
      category,
      reason,
    });
    if (out.length >= maxPatches) break;
  }

  out.sort((a, b) => a.start - b.start);
  return {
    patches: out,
    stats: {
      proposed: list.length,
      kept: out.length,
      dropped: Math.max(0, list.length - out.length),
    },
  };
}

/**
 * Remap selection-relative patches onto full-body offsets.
 * @param {unknown[]} patches
 * @param {number} base
 */
export function remapPatchOffsets(patches, base) {
  const b = Number(base) || 0;
  return (Array.isArray(patches) ? patches : []).map((p) => ({
    ...p,
    start: Number(p.start) + b,
    end: Number(p.end) + b,
  }));
}
