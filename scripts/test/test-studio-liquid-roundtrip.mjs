#!/usr/bin/env node
/**
 * AC-STU-03, AC-STU-04 — Liquid include round-trip without TipTap URL mangling.
 * Spec: docs/features/studio.md
 */
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "../..");

// Import from studio-app source (Node-friendly pure helpers).
const liquidPath = path.join(root, "studio-app/src/editor/liquid-core.js");
const { attrsToInclude, parseIncludes, INCLUDE_DEFS, roundTripMarkdown } =
  await import(liquidPath);
const { splitDocument, rebuildDocument } = await import(
  path.join(root, "studio-app/src/lib/document.js")
);

const remote =
  'https://vejasp.abril.com.br/wp-content/uploads/2016/11/12209_drone-zangao.jpeg';

const figureDef = INCLUDE_DEFS.find((d) => d.name === "figure");
const serialized = attrsToInclude(figureDef, {
  src: remote,
  caption: "Skydrones Zangão V",
  width: "100",
});

assert.match(serialized, /include figure\.html/);
assert.equal(serialized.includes(`src="${remote}"`), true);
assert.equal(serialized.includes(`src="[${remote}](${remote})"`), false);

const roundTrip = parseIncludes(serialized);
assert.equal(roundTrip.length, 1);
assert.equal(roundTrip[0].type, "include");
assert.equal(roundTrip[0].attrs.src, remote);

const markdown = [
  "Intro paragraph.",
  "",
  serialized,
  "",
  "After.",
].join("\n");

const segments = parseIncludes(markdown);
assert.equal(segments.filter((s) => s.type === "include").length, 1);
assert.equal(segments.find((s) => s.type === "include").attrs.src, remote);

const yt = attrsToInclude(
  INCLUDE_DEFS.find((d) => d.name === "youtube"),
  { id: "dQw4w9WgXcQ", caption: "demo", width: "80%" }
);
assert.match(yt, /youtube\.html/);
assert.match(yt, /id="dQw4w9WgXcQ"/);
assert.match(yt, /width="80%"/);

const ytParsed = parseIncludes(yt);
assert.equal(ytParsed.length, 1);
assert.equal(ytParsed[0].type, "include");
assert.equal(ytParsed[0].attrs.id, "dQw4w9WgXcQ");
assert.equal(ytParsed[0].attrs.width, "80%");

// Published form: percent width inside quoted attrs must still parse.
const ytPublished = `{% include youtube.html id="zeJD6dqJ5lo" width="80%" %}`;
const ytPubSeg = parseIncludes(ytPublished);
assert.equal(ytPubSeg.length, 1);
assert.equal(ytPubSeg[0].attrs.id, "zeJD6dqJ5lo");
assert.equal(ytPubSeg[0].attrs.width, "80%");

// Percent-encoded URLs in attrs must not truncate at `%`.
const encodedSrc =
  "https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/foo%2C_bar.jpg/1280px-foo.jpg";
const figEncoded = attrsToInclude(figureDef, {
  src: encodedSrc,
  caption: "encoded",
  width: "85",
});
const figSeg = parseIncludes(figEncoded);
assert.equal(figSeg[0].attrs.src, encodedSrc);

const xc = attrsToInclude(INCLUDE_DEFS.find((d) => d.name === "xcite"), {
  key: "studio-cms",
});
assert.match(xc, /xcite\.html/);
assert.match(xc, /key="studio-cms"/);
assert.equal(xc.includes("\n"), false);

const figureMany = attrsToInclude(figureDef, {
  src: "/media/images/website/studio-editor-light.png",
  alt: "Studio with a sample draft",
  caption: "A draft open beside its preview.",
  source: "Author",
  width: "100",
});
assert.equal(
  figureMany,
  '{% include figure.html src="/media/images/website/studio-editor-light.png" alt="Studio with a sample draft" caption="A draft open beside its preview." source="Author" width="100" %}'
);

const inline =
  'The earlier account, {% include xcite.html key="studio-cms" %}, records that room, and {% include xcite.html key="headless-architecture" %} records how a save reaches the visitor.\n';
assert.equal(roundTripMarkdown(inline), inline);

const figures = [
  '{% include figure.html src="/media/images/website/studio-articles-light.png" alt="List" caption="Articles in Studio." source="Author" width="100" %}',
  "",
  '{% include figure.html src="/media/images/website/studio-editor-light.png" alt="Editor" caption="A draft open beside its preview." source="Author" width="100" %}',
  "",
  "## Beauty in the writing room",
  "",
  "I am happy with it again.",
  "",
].join("\n");
assert.equal(roundTripMarkdown(figures), figures);

const keptFigure = `{% include figure.html src="https://decapcms.org/img/screenshot-editor.png" caption="Decap was a proof of concept." source="decapcms.org" width="100" %}`;
assert.equal(roundTripMarkdown(`${keptFigure}\n`), `${keptFigure}\n`);

const multilineVideo = `{% include video.html
  src="https://example.com/demo.mp4"
  caption="A demo."
  width="80"
%}`;
assert.equal(roundTripMarkdown(`${multilineVideo}\n`), `${multilineVideo}\n`);

for (const name of ["youtube", "youtube-short", "video", "plotly", "cut-in", "cite"]) {
  const def = INCLUDE_DEFS.find((d) => d.include === `${name}.html` || d.include === name);
  assert.ok(def, name);
  const attrs = {};
  for (const field of def.fields) {
    if (field === "body") continue;
    attrs[field] = field === "width" ? "80%" : `${field}-value`;
  }
  const line = attrsToInclude(def, attrs);
  assert.equal(line.includes("\n"), false, name);
  const again = roundTripMarkdown(`${line}\n`);
  assert.equal(again, `${line}\n`, name);
}

const original = `---
layout: article
title: If you want it done well, do it yourself
date: 2026-10-02
description: How the writing room on this site became an editor I built, measured to the includes the pages already use.
thumbnail: /media/images/website/studio-editor-light.png
tags:
  - AI
  - Aesthetics
  - DevOps
language: enus
mermaid: true
published: false
key: if-you-want-it-done-well
---
The earlier account, {% include xcite.html key="studio-cms" %}, records that room.

`;
const split = splitDocument(original);
assert.deepEqual(split.fm.tags, ["AI", "Aesthetics", "DevOps"]);
assert.equal(split.fm.title, "If you want it done well, do it yourself");
const rebuilt = rebuildDocument(original, {
  fields: { ...split.fm, thumbnail: "" },
  body: split.body,
  format: "yaml-frontmatter",
});
assert.equal(rebuilt.includes("thumbnail:"), false);
assert.match(rebuilt, /^title: If you want it done well, do it yourself$/m);
assert.match(rebuilt, /tags:\n  - AI\n  - Aesthetics\n  - DevOps\n/);
assert.match(
  rebuilt,
  /The earlier account, \{% include xcite\.html key="studio-cms" %\}, records that room\./
);
assert.equal(rebuilt.includes('title: "'), false);

console.log("All Studio liquid round-trip checks passed.");
