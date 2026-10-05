/**
 * Gemini prompt builders for Studio Correct / Refine.
 * Spec: docs/features/studio-proof.md §8 (AC-PRF-11, AC-PRF-15, AC-PRF-17).
 */

import { formatBlocksForPrompt } from "./blocks.js";

const CORRECT_SCHEMA = {
  type: "object",
  properties: {
    patches: {
      type: "array",
      items: {
        type: "object",
        required: ["start", "end", "original", "replacement", "category", "reason"],
        properties: {
          start: { type: "integer" },
          end: { type: "integer" },
          original: { type: "string" },
          replacement: { type: "string" },
          category: { type: "string" },
          reason: { type: "string" },
        },
      },
    },
  },
  required: ["patches"],
};

const REFINE_SCHEMA = {
  type: "object",
  properties: {
    patches: {
      type: "array",
      items: {
        type: "object",
        required: ["block", "original", "replacement", "category", "reason"],
        properties: {
          block: { type: "integer" },
          original: { type: "string" },
          replacement: { type: "string" },
          category: { type: "string" },
          reason: { type: "string" },
        },
      },
    },
  },
  required: ["patches"],
};

const CORRECT_SYSTEM = `You are a mechanical corrector for a personal site CMS. You are not a co-author and not a stylist.

Language: all judgments use the language code from the user message (from the entry front matter). Spelling and idiom follow that language's norms.

Allowed patch categories only: spelling, typo, grammar, punctuation, idiom. If unsure whether a change is required for correctness, omit it.

Hard bans:
- Do not improve rhythm, voice, imagery, or “style”.
- Do not change meaning, add or remove ideas, or reorder paragraphs.
- Do not edit Liquid {% … %} tags (include, cite, or any other) or their attributes.
- Do not touch fenced code blocks or inline \`code\`.
- Do not translate into another language.
- Do not invent citations, links, or facts.

Offsets start/end are JavaScript string indices (UTF-16 code units) into the exact text field. original must equal text.slice(start, end). Prefer the smallest edit that makes the sentence correct.

Emit JSON only matching the schema. No prose outside JSON.`;

function refineSystem(guidelinesBody) {
  const pack = String(guidelinesBody || "").trim();
  return `You are an editorial refiner for a personal site CMS under the owner's writing law. The user invoked Refine on purpose: improve fluidity, clarity, correctness, and prose quality inside the submitted blocks. You are not a co-author: do not change stance, invent structure, headings hierarchy, or claims.

Preserve tone consistency with the submitted text and with any provided article context (before/after). Stay in the language code from the user message.

Allowed patch categories: clarity, flow, prose, grammar, punctuation, spelling, typo, idiom.

When to patch:
- For each prose block, look for sentences that can be tightened, clarified, or made to flow better without changing meaning.
- Prefer one local edit per issue (a clause or a sentence). original must be an exact substring of that block.
- Skip heading-only blocks, blocks that are only Liquid/HTML, and figure/include-only blocks.
- Empty patches only when every prose block is already tight under the guidelines. Do not return an empty list just because the prose is already good if a clearer local wording exists.

Hard bans:
- Do not edit Liquid {% … %} tags (include, cite, or any other) or code fences / inline code. Leave those substrings untouched inside original/replacement.
- Do not translate.
- Do not homogenize into generic AI-essay voice, mic-drop closers, or banned patterns from the guidelines.
- Do not leak private repository paths or internal tooling into the prose.
- Do not replace an entire long paragraph in one patch; keep each replacement short and local.

Each patch must set block to the integer index shown as [n] in the user message.

Writing guidelines (published pack):
<<<
${pack}
>>>

Emit JSON only matching the schema. No prose outside JSON.`;
}

/**
 * Prefer Fundamental + Cadence/Typography + site overlay if over budget.
 * @param {string} body
 * @param {number} maxChars
 */
export function truncateGuidelines(body, maxChars = 48_000) {
  const text = String(body || "");
  if (text.length <= maxChars) return text;
  return `${text.slice(0, maxChars)}\n\n[guidelines truncated for context budget]\n`;
}

/**
 * @param {object} opts
 * @param {"correct"|"refine"} opts.mode
 * @param {string} opts.language
 * @param {string} opts.path
 * @param {string} opts.text
 * @param {{ before?: string, after?: string } | null} [opts.context]
 * @param {string} [opts.guidelinesBody]
 * @param {{ index: number, text: string }[] | null} [opts.blocks]
 */
export function buildGeminiRequest({
  mode,
  language,
  path,
  text,
  context = null,
  guidelinesBody = "",
  blocks = null,
}) {
  const system =
    mode === "refine"
      ? refineSystem(truncateGuidelines(guidelinesBody))
      : CORRECT_SYSTEM;

  const parts = [
    `mode: ${mode}`,
    `language: ${language}`,
    `path: ${path || ""}`,
  ];
  if (mode === "refine" && context?.before) {
    parts.push("context.before:", "<<<", String(context.before), ">>>");
  }
  if (mode === "refine" && Array.isArray(blocks) && blocks.length) {
    parts.push(formatBlocksForPrompt(blocks));
  } else {
    parts.push("text:", "<<<", String(text ?? ""), ">>>");
  }
  if (mode === "refine" && context?.after) {
    parts.push("context.after:", "<<<", String(context.after), ">>>");
  }

  return {
    systemInstruction: { parts: [{ text: system }] },
    contents: [{ role: "user", parts: [{ text: parts.join("\n") }] }],
    generationConfig: {
      temperature: mode === "refine" ? 0.35 : 0,
      responseMimeType: "application/json",
      responseSchema: mode === "refine" ? REFINE_SCHEMA : CORRECT_SCHEMA,
    },
  };
}

export { CORRECT_SCHEMA, REFINE_SCHEMA, CORRECT_SYSTEM };
/** @deprecated use CORRECT_SCHEMA — kept for static contract greps */
export const RESPONSE_SCHEMA = CORRECT_SCHEMA;
