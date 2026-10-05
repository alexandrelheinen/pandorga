#!/usr/bin/env node
/**
 * AC-PRF-05, AC-PRF-06, AC-PRF-07, AC-PRF-15 — patch sanitizer + block chunking.
 * Spec: docs/features/studio-proof.md §8
 */
import assert from "node:assert/strict";
import {
  flattenBlockPatches,
  locateUnique,
  splitIntoBlocks,
} from "../../functions/api/studio/_lib/blocks.js";
import { sanitizePatches } from "../../functions/api/studio/_lib/sanitize.js";
import {
  buildGeminiRequest,
  truncateGuidelines,
} from "../../functions/api/studio/_lib/prompts.js";

const text =
  'Hello wrld.\n\n{% include figure.html src="/media/x.png" %}\n\n`code` and ```\nfence\n```\n';

{
  const { patches, stats } = sanitizePatches({
    mode: "correct",
    text,
    patches: [
      {
        start: 6,
        end: 10,
        original: "wrld",
        replacement: "world",
        category: "spelling",
        reason: "typo",
      },
      {
        start: 6,
        end: 10,
        original: "NOPE",
        replacement: "world",
        category: "spelling",
        reason: "bad",
      },
      {
        start: text.indexOf("{%"),
        end: text.indexOf("%}") + 2,
        original: text.slice(text.indexOf("{%"), text.indexOf("%}") + 2),
        replacement: "x",
        category: "grammar",
        reason: "include",
      },
      {
        start: 0,
        end: 5,
        original: "Hello",
        replacement: "Hiya!",
        category: "clarity",
        reason: "style",
      },
    ],
  });
  assert.equal(patches.length, 1);
  assert.equal(patches[0].replacement, "world");
  assert.equal(stats.kept, 1);
  assert.ok(stats.dropped >= 1);
}

{
  // Offset recovery: wrong start/end, exact original still locates.
  const { patches } = sanitizePatches({
    mode: "correct",
    text: "alpha beta gamma",
    patches: [
      {
        start: 99,
        end: 103,
        original: "beta",
        replacement: "BETA",
        category: "spelling",
        reason: "case",
      },
    ],
  });
  assert.equal(patches.length, 1);
  assert.equal(patches[0].start, 6);
  assert.equal(patches[0].end, 10);
}

{
  const { patches } = sanitizePatches({
    mode: "refine",
    text: "A clunky sentence here.",
    patches: [
      {
        start: 0,
        end: 23,
        original: "A clunky sentence here.",
        replacement: "A clearer sentence here.",
        category: "clarity",
        reason: "flow",
      },
    ],
  });
  assert.equal(patches.length, 1);
  assert.equal(patches[0].category, "clarity");
}

{
  // {% cite %} is protected like include.
  const src = "Antes {% cite turino-2008 %} depois.";
  const cite = "{% cite turino-2008 %}";
  const at = src.indexOf(cite);
  const { patches } = sanitizePatches({
    mode: "refine",
    text: src,
    patches: [
      {
        start: at,
        end: at + cite.length,
        original: cite,
        replacement: "REMOVED",
        category: "clarity",
        reason: "bad",
      },
    ],
  });
  assert.equal(patches.length, 0);
}

{
  const body =
    "First paragraph here.\n\nSecond paragraph here.\n\n## Heading\n\nThird paragraph with more words to grow.";
  const blocks = splitIntoBlocks(body, { targetChars: 40, maxChars: 80 });
  assert.ok(blocks.length >= 2);
  assert.equal(blocks[0].start, 0);
  assert.equal(body.slice(blocks[0].start, blocks[0].end), blocks[0].text);
  const joined = blocks.map((b) => b.text).join("");
  // Separators are kept on preceding blocks; concatenation should rebuild body.
  assert.equal(joined, body);
}

{
  const body = "Alpha one.\n\nBeta two.\n\nGamma three.";
  const blocks = splitIntoBlocks(body, { targetChars: 10, maxChars: 20 });
  const flat = flattenBlockPatches(blocks, [
    {
      block: 1,
      original: "Beta two.",
      replacement: "Beta too.",
      category: "clarity",
      reason: "tight",
    },
  ]);
  assert.equal(flat.length, 1);
  assert.equal(body.slice(flat[0].start, flat[0].end), "Beta two.");
}

{
  const hit = locateUnique("aa bb aa", "aa", 5);
  assert.equal(hit.start, 6);
}

{
  const req = buildGeminiRequest({
    mode: "correct",
    language: "en",
    path: "content/collections/articles/x.md",
    text: "teh",
  });
  const sys = req.systemInstruction.parts[0].text;
  assert.ok(sys.includes("mechanical corrector"));
  assert.ok(!sys.includes("Writing guidelines (published pack)"));
  assert.equal(
    req.generationConfig.responseSchema.properties.patches.items.required.includes(
      "start"
    ),
    true
  );
}

{
  const blocks = splitIntoBlocks("Short prose for refine.\n\nAnother beat.");
  const req = buildGeminiRequest({
    mode: "refine",
    language: "pt-BR",
    path: "content/collections/posts/x.md",
    text: "Short prose for refine.\n\nAnother beat.",
    guidelinesBody: "You are not a co-author.\n",
    blocks,
  });
  const sys = req.systemInstruction.parts[0].text;
  const user = req.contents[0].parts[0].text;
  assert.ok(sys.includes("tone consistency") || sys.includes("Preserve tone"));
  assert.ok(sys.includes("not a co-author"));
  assert.ok(sys.includes("invoked Refine"));
  assert.ok(user.includes("blocks:"));
  assert.ok(user.includes("[0]"));
  assert.ok(
    req.generationConfig.responseSchema.properties.patches.items.required.includes(
      "block"
    )
  );
}

{
  const long = "a".repeat(100);
  const truncated = truncateGuidelines(long, 50);
  assert.ok(truncated.length < long.length);
  assert.ok(truncated.includes("truncated"));
}

console.log("All Studio rewrite sanitize checks passed.");
