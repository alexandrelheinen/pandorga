/**
 * Pure Liquid include serialize/parse helpers (no TipTap).
 * Used by the editor and by scripts/test/test-studio-liquid-roundtrip.mjs.
 */

export const INCLUDE_DEFS = [
  {
    name: "figure",
    include: "figure.html",
    label: "Figure",
    fields: ["src", "alt", "caption", "source", "width"],
  },
  {
    name: "cutIn",
    include: "cut-in.html",
    label: "Cut-in",
    fields: ["src", "alt", "side"],
  },
  {
    name: "youtube",
    include: "youtube.html",
    label: "YouTube",
    fields: ["id", "caption", "width"],
  },
  {
    name: "youtubeShort",
    include: "youtube-short.html",
    label: "YouTube Short",
    fields: ["src", "src2"],
  },
  {
    name: "video",
    include: "video.html",
    label: "Video",
    fields: ["src", "caption", "width"],
  },
  {
    name: "plotly",
    include: "plotly.html",
    label: "Plotly",
    fields: ["src", "caption", "width", "height", "source", "alt"],
  },
  {
    name: "xcite",
    include: "xcite.html",
    label: "Xcite",
    fields: ["key"],
    inline: true,
  },
  {
    name: "cite",
    include: "cite.html",
    label: "Cite",
    fields: ["key"],
    inline: true,
  },
  {
    name: "articleNote",
    include: "article-note",
    label: "Article note",
    fields: ["body"],
    blockBody: true,
  },
  {
    name: "poem",
    include: "poem",
    label: "Poem",
    fields: ["body"],
    blockBody: true,
  },
];

export function attrsToInclude(def, attrs) {
  if (def.blockBody) {
    const body = attrs.body || "";
    return `{% include ${def.include} markdown="1" %}\n${body}\n{% endinclude %}`;
  }
  const parts = def.fields
    .filter((f) => attrs[f] != null && String(attrs[f]).length)
    .map((f) => `${f}="${String(attrs[f]).replace(/"/g, "&quot;")}"`);
  if (!parts.length) return `{% include ${def.include} %}`;
  return `{% include ${def.include} ${parts.join(" ")} %}`;
}

export function parseIncludes(markdown) {
  const text = String(markdown || "");
  const segments = [];
  // Stop at `%}` only — attrs often contain `%` (width="80%", percent-encoded URLs).
  const selfRe = /\{%-?\s*include\s+([\w.-]+)\s*((?:(?!%\})[\s\S])*?)\s*-?%\}/g;
  let last = 0;
  let m;
  while ((m = selfRe.exec(text))) {
    const includeName = m[1];
    const def = INCLUDE_DEFS.find((d) => d.include === includeName);
    if (!def || def.blockBody) continue;
    if (m.index > last) {
      segments.push({ type: "text", text: text.slice(last, m.index) });
    }
    const attrs = parseAttrString(m[2]);
    segments.push({ type: "include", def, attrs, raw: m[0] });
    last = m.index + m[0].length;
  }
  if (last < text.length) {
    segments.push({ type: "text", text: text.slice(last) });
  }
  return segments;
}

function parseAttrString(raw) {
  const attrs = {};
  String(raw || "").replace(
    /([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/g,
    (_, key, d, s) => {
      attrs[key] = d != null ? d : s;
      return "";
    }
  );
  return attrs;
}

const INCLUDE_RE =
  /\{%-?\s*include\s+([\w.-]+)\s*((?:(?!%\})[\s\S])*?)\s*-?%\}/g;

function defForInclude(includeName) {
  return INCLUDE_DEFS.find((d) => d.include === includeName);
}

/** A chunk that is one include and nothing else, newlines inside the tag allowed. */
function matchSoloInclude(chunk) {
  const t = String(chunk || "").trim();
  if (!t.startsWith("{%")) return null;
  const block = t.match(
    /^\{%-?\s*include\s+([\w.-]+)\b[^%]*?-?%\}\s*([\s\S]*?)\s*\{%-?\s*endinclude\s*-?%\}$/
  );
  if (block) {
    const def = defForInclude(block[1]);
    if (!def?.blockBody) return null;
    return {
      type: def.name,
      attrs: { body: block[2].replace(/^\n|\n$/g, ""), raw: t },
    };
  }
  const self = t.match(
    /^\{%-?\s*include\s+([\w.-]+)\s*((?:(?!%\})[\s\S])*?)\s*-?%\}$/
  );
  if (!self) return null;
  const def = defForInclude(self[1]);
  if (!def || def.inline || def.blockBody) return null;
  return includeNode(def, self[2], self[0]);
}

function includeNode(def, attrSource, raw) {
  return {
    type: def.name,
    attrs: { ...parseAttrString(attrSource), raw },
  };
}

function rawStillMatches(def, attrs) {
  const raw = attrs?.raw;
  if (typeof raw !== "string" || !raw) return false;
  if (def.blockBody) {
    const current = attrs.body == null ? "" : String(attrs.body);
    return raw.includes(current);
  }
  const fromRaw = parseAttrString(raw);
  for (const field of def.fields) {
    const current = attrs[field] == null ? "" : String(attrs[field]);
    const original = fromRaw[field] == null ? "" : String(fromRaw[field]);
    if (current !== original) return false;
  }
  return true;
}

function includeMarkdown(def, attrs) {
  if (rawStillMatches(def, attrs)) return attrs.raw;
  return attrsToInclude(def, attrs);
}

function paragraphNodes(text) {
  const src = String(text || "");
  const nodes = [];
  const re = new RegExp(INCLUDE_RE.source, "g");
  let last = 0;
  let m;
  while ((m = re.exec(src))) {
    if (m.index > last) {
      nodes.push({ type: "text", text: src.slice(last, m.index) });
    }
    const def = defForInclude(m[1]);
    if (def?.inline) {
      nodes.push(includeNode(def, m[2], m[0]));
    } else {
      nodes.push({ type: "text", text: m[0] });
    }
    last = m.index + m[0].length;
  }
  if (last < src.length) {
    nodes.push({ type: "text", text: src.slice(last) });
  }
  return nodes.filter((n) => n.type !== "text" || n.text !== "");
}

function stripOuterBlankLines(chunk) {
  return String(chunk || "").replace(/^\n+|\n+$/g, "");
}

function pushPlainChunk(content, text) {
  const line = stripOuterBlankLines(text);
  if (!line) return;
  const heading = line.match(/^(#{1,6})\s+([\s\S]*)$/);
  if (heading && !line.includes("\n") && line.trim() === line) {
    content.push({
      type: "heading",
      attrs: { level: heading[1].length },
      content: paragraphNodes(heading[2]),
    });
    return;
  }
  content.push({ type: "paragraph", content: paragraphNodes(line) });
}

function pushRichChunk(content, chunk) {
  const trimmed = stripOuterBlankLines(chunk);
  if (!trimmed) return;
  const solo = matchSoloInclude(trimmed);
  if (solo) {
    content.push(solo);
    return;
  }

  const re = new RegExp(INCLUDE_RE.source, "g");
  const parts = [];
  let last = 0;
  let m;
  let sawBlock = false;
  while ((m = re.exec(trimmed))) {
    const def = defForInclude(m[1]);
    if (def && !def.inline && !def.blockBody) {
      sawBlock = true;
      parts.push({ kind: "text", text: trimmed.slice(last, m.index) });
      parts.push({
        kind: "block",
        node: includeNode(def, m[2], m[0]),
      });
      last = m.index + m[0].length;
    }
  }
  if (!sawBlock) {
    pushPlainChunk(content, trimmed);
    return;
  }
  parts.push({ kind: "text", text: trimmed.slice(last) });
  for (const part of parts) {
    if (part.kind === "block") content.push(part.node);
    else if (part.text.trim()) pushPlainChunk(content, part.text);
  }
}

function pushMarkdownChunks(content, text) {
  const fenceRe = /```([^\n`]*)\n([\s\S]*?)```/g;
  let last = 0;
  let m;
  const src = String(text || "");
  while ((m = fenceRe.exec(src))) {
    if (m.index > last) pushProseChunks(content, src.slice(last, m.index));
    const lang = String(m[1] || "").trim();
    const code = String(m[2] || "").replace(/\n$/, "");
    content.push({
      type: "codeBlock",
      attrs: { language: lang || null },
      content: code ? [{ type: "text", text: code }] : [],
    });
    last = m.index + m[0].length;
  }
  if (last < src.length) pushProseChunks(content, src.slice(last));
}

function pushProseChunks(content, text) {
  const chunks = String(text || "").split(/\n{2,}/);
  for (const chunk of chunks) pushRichChunk(content, chunk);
}

export function markdownToEditorContent(markdown) {
  const content = [];
  pushMarkdownChunks(content, markdown);
  if (!content.length) content.push({ type: "paragraph" });
  return { type: "doc", content };
}

function inlineToMd(nodes) {
  return (nodes || [])
    .map((n) => {
      if (n.type === "text") {
        let t = n.text || "";
        const marks = n.marks || [];
        for (const mark of marks) {
          if (mark.type === "bold") t = `**${t}**`;
          if (mark.type === "italic") t = `*${t}*`;
          if (mark.type === "strike") t = `~~${t}~~`;
          if (mark.type === "code") t = `\`${t}\``;
          if (mark.type === "link") t = `[${t}](${mark.attrs?.href || ""})`;
          if (mark.type === "textStyle" && mark.attrs?.color) {
            t = `<span style="color:${mark.attrs.color}">${t}</span>`;
          }
        }
        return t;
      }
      if (n.type === "hardBreak") return "  \n";
      const def = INCLUDE_DEFS.find((d) => d.name === n.type);
      if (def) return includeMarkdown(def, n.attrs || {});
      return "";
    })
    .join("");
}

function nodesToMarkdown(nodes) {
  return (nodes || [])
    .map((node) => {
      const def = INCLUDE_DEFS.find((d) => d.name === node.type);
      if (def) {
        const block = includeMarkdown(def, node.attrs || {});
        return block.endsWith("\n") ? `${block}\n` : `${block}\n\n`;
      }
      switch (node.type) {
        case "paragraph":
          return `${inlineToMd(node.content || [])}\n\n`;
        case "heading": {
          const level = node.attrs?.level || 1;
          return `${"#".repeat(level)} ${inlineToMd(node.content || [])}\n\n`;
        }
        case "blockquote":
          return (
            nodesToMarkdown(node.content || [])
              .split("\n")
              .map((l) => (l ? `> ${l}` : ">"))
              .join("\n") + "\n\n"
          );
        case "bulletList":
          return (
            (node.content || [])
              .map((li) => `- ${nodesToMarkdown(li.content || []).trim()}`)
              .join("\n") + "\n\n"
          );
        case "orderedList":
          return (
            (node.content || [])
              .map(
                (li, i) =>
                  `${i + 1}. ${nodesToMarkdown(li.content || []).trim()}`
              )
              .join("\n") + "\n\n"
          );
        case "codeBlock": {
          const lang = node.attrs?.language || "";
          return (
            "```" +
            lang +
            "\n" +
            (node.content || []).map((c) => c.text || "").join("") +
            "\n```\n\n"
          );
        }
        case "horizontalRule":
          return "---\n\n";
        default:
          if (node.content) return nodesToMarkdown(node.content);
          return "";
      }
    })
    .join("");
}

export function serializeContent(nodes) {
  return nodesToMarkdown(nodes).trim() + "\n";
}

/** Parse then serialize. Includes stay inline or one line, with the spaces around them. */
export function roundTripMarkdown(markdown) {
  const doc = markdownToEditorContent(markdown);
  return serializeContent(doc.content || []);
}
