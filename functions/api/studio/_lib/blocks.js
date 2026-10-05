/**
 * Paragraph/block chunking for Studio Refine.
 * Large selections get local patches per block; absolute offsets are remapped after.
 */

const DEFAULT_TARGET = 1_800;
const DEFAULT_MAX = 2_400;

/**
 * Split markdown into contiguous blocks with absolute offsets into `text`.
 * Breaks on blank lines (separators stay with the preceding block); merges small
 * siblings up to targetChars without exceeding maxChars unless one segment is larger.
 *
 * @param {string} text
 * @param {{ targetChars?: number, maxChars?: number }} [opts]
 * @returns {{ index: number, start: number, end: number, text: string }[]}
 */
export function splitIntoBlocks(text, opts = {}) {
  const targetChars = opts.targetChars ?? DEFAULT_TARGET;
  const maxChars = opts.maxChars ?? DEFAULT_MAX;
  const src = typeof text === "string" ? text : "";
  if (!src) return [];

  const chunks = src.split(/(\n{2,})/);
  const segments = [];
  let pos = 0;
  for (const piece of chunks) {
    if (!piece) continue;
    const next = pos + piece.length;
    if (/^\n{2,}$/.test(piece)) {
      if (segments.length) {
        const prev = segments[segments.length - 1];
        prev.end = next;
        prev.text = src.slice(prev.start, prev.end);
      } else {
        segments.push({ start: pos, end: next, text: piece });
      }
    } else {
      segments.push({ start: pos, end: next, text: piece });
    }
    pos = next;
  }
  if (!segments.length) {
    return [{ index: 0, start: 0, end: src.length, text: src }];
  }

  const merged = [];
  let buf = null;
  for (const seg of segments) {
    if (!buf) {
      buf = { start: seg.start, end: seg.end, text: seg.text };
      continue;
    }
    const combinedLen = buf.end - buf.start + (seg.end - seg.start);
    if (buf.text.trim().length < targetChars && combinedLen <= maxChars) {
      buf.end = seg.end;
      buf.text = src.slice(buf.start, buf.end);
    } else {
      merged.push(buf);
      buf = { start: seg.start, end: seg.end, text: seg.text };
    }
  }
  if (buf) merged.push(buf);

  return merged.map((b, index) => ({
    index,
    start: b.start,
    end: b.end,
    text: b.text,
  }));
}

/**
 * Find a unique (or hint-disambiguated) occurrence of `needle` in `haystack`.
 * @param {string} haystack
 * @param {string} needle
 * @param {number} [hint]
 * @returns {{ start: number, end: number } | null}
 */
export function locateUnique(haystack, needle, hint = 0) {
  if (!needle || typeof haystack !== "string") return null;
  const h = Number.isInteger(hint) ? hint : 0;
  if (h >= 0 && haystack.slice(h, h + needle.length) === needle) {
    return { start: h, end: h + needle.length };
  }
  const hits = [];
  let from = 0;
  while (from <= haystack.length - needle.length) {
    const i = haystack.indexOf(needle, from);
    if (i === -1) break;
    hits.push(i);
    from = i + 1;
  }
  if (!hits.length) return null;
  if (hits.length === 1) {
    return { start: hits[0], end: hits[0] + needle.length };
  }
  let best = hits[0];
  let bestDist = Math.abs(best - h);
  for (const i of hits) {
    const d = Math.abs(i - h);
    if (d < bestDist) {
      best = i;
      bestDist = d;
    }
  }
  return { start: best, end: best + needle.length };
}

/**
 * Map block-scoped patches onto absolute offsets in the full work text.
 * @param {{ index: number, start: number, end: number, text: string }[]} blocks
 * @param {unknown[]} patches
 * @returns {unknown[]}
 */
export function flattenBlockPatches(blocks, patches) {
  const list = Array.isArray(patches) ? patches : [];
  const byIndex = new Map(
    (Array.isArray(blocks) ? blocks : []).map((b) => [b.index, b])
  );
  const out = [];
  for (const raw of list) {
    if (!raw || typeof raw !== "object") continue;
    const blockIndex = Number(raw.block);
    if (!Number.isInteger(blockIndex)) continue;
    const block = byIndex.get(blockIndex);
    if (!block) continue;
    const original = String(raw.original ?? "");
    const replacement = String(raw.replacement ?? "");
    if (!original || replacement === original) continue;
    const hint = Number.isInteger(Number(raw.start)) ? Number(raw.start) : 0;
    const loc = locateUnique(block.text, original, hint);
    if (!loc) continue;
    out.push({
      start: block.start + loc.start,
      end: block.start + loc.end,
      original,
      replacement,
      category: raw.category,
      reason: raw.reason,
    });
  }
  return out;
}

/**
 * Format blocks for the Gemini user message.
 * @param {{ index: number, text: string }[]} blocks
 */
export function formatBlocksForPrompt(blocks) {
  const lines = ["blocks:"];
  for (const b of blocks) {
    lines.push(`[${b.index}]`, "<<<", b.text, ">>>");
  }
  return lines.join("\n");
}
