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

function isWordChar(ch) {
  return !!ch && /[\p{L}\p{N}]/u.test(ch);
}

/**
 * Wrapped emphasis (`*`, `_`, `**`, `__`, `***`, `___`, `~~`).
 * Flanking matches the editor: not inside a word, not a longer run of the
 * same marker, and the inside does not start or end with space. The inside
 * may contain the other delimiter, so `**bold _and_ more**` and `***both***`
 * reopen as the same marks the preview paints.
 */
function matchWrapped(src, i, marker) {
  if (!src.startsWith(marker, i)) return null;
  const sym = marker[0];
  const uniform = [...marker].every((c) => c === sym);
  if (uniform && src[i + marker.length] === sym) return null;
  if (isWordChar(src[i - 1])) return null;
  const innerStart = i + marker.length;
  if (!src[innerStart] || /\s/.test(src[innerStart])) return null;
  for (let j = innerStart + 1; j < src.length; j++) {
    if (src[j] === "\n") return null;
    if (src[j] === "\\") {
      j += 1;
      continue;
    }
    if (src[j] === "`") {
      const code = src.slice(j).match(/^`[^`\n]+`/);
      if (code) {
        j += code[0].length - 1;
        continue;
      }
    }
    if (!src.startsWith(marker, j)) continue;
    if (uniform && src[j + marker.length] === sym) continue;
    if (/\s/.test(src[j - 1])) continue;
    if (isWordChar(src[j + marker.length])) continue;
    const text = src.slice(innerStart, j);
    if (!text) return null;
    return { text, length: j + marker.length - i };
  }
  return null;
}

function withMark(node, mark) {
  if (!mark || node.type !== "text") return node;
  // Index 0 is the outer mark, matching ProseMirror (lower schema rank first).
  return { ...node, marks: [mark, ...(node.marks || [])] };
}

/** Inline marks the visual editor and the saved Markdown share. */
function parseInline(src) {
  const nodes = [];
  let i = 0;
  let buf = "";
  const flush = () => {
    if (!buf) return;
    nodes.push({ type: "text", text: buf });
    buf = "";
  };
  const take = (inner, mark, rawLength) => {
    flush();
    const marks = Array.isArray(mark) ? mark : [mark];
    for (const node of parseInline(inner)) {
      let next = node;
      for (let n = marks.length - 1; n >= 0; n -= 1) next = withMark(next, marks[n]);
      nodes.push(next);
    }
    i += rawLength;
  };

  while (i < src.length) {
    const rest = src.slice(i);
    if (rest.startsWith("  \n")) {
      flush();
      nodes.push({ type: "hardBreak" });
      i += 3;
      continue;
    }
    let m = rest.match(/^`([^`\n]+)`/);
    if (m) {
      flush();
      nodes.push({ type: "text", text: m[1], marks: [{ type: "code" }] });
      i += m[0].length;
      continue;
    }
    m = rest.match(/^<span style="color:([^"]+)">([\s\S]*?)<\/span>/);
    if (m) {
      take(m[2], { type: "textStyle", attrs: { color: m[1] } }, m[0].length);
      continue;
    }
    m = rest.match(/^\[([^\]\n]+)\]\(([^)\s]+)\)/);
    if (m) {
      take(m[1], { type: "link", attrs: { href: m[2] } }, m[0].length);
      continue;
    }
    const strike = matchWrapped(src, i, "~~");
    if (strike) {
      take(strike.text, { type: "strike" }, strike.length);
      continue;
    }
    const both = ["***", "___"]
      .map((marker) => ({ marker, hit: matchWrapped(src, i, marker) }))
      .find((row) => row.hit);
    if (both) {
      take(
        both.hit.text,
        [{ type: "bold" }, { type: "italic" }],
        both.hit.length
      );
      continue;
    }
    const strong = ["**", "__"]
      .map((marker) => matchWrapped(src, i, marker))
      .find(Boolean);
    if (strong) {
      take(strong.text, { type: "bold" }, strong.length);
      continue;
    }
    const em = [matchWrapped(src, i, "*"), matchWrapped(src, i, "_")].find(Boolean);
    if (em) {
      take(em.text, { type: "italic" }, em.length);
      continue;
    }
    buf += src[i];
    i += 1;
  }
  flush();
  return nodes;
}

function pushParsedText(nodes, text) {
  if (!text) return;
  for (const node of parseInline(text)) {
    if (node.type === "text" && node.text === "") continue;
    nodes.push(node);
  }
}

function paragraphNodes(text) {
  const src = String(text || "");
  const nodes = [];
  const re = new RegExp(INCLUDE_RE.source, "g");
  let last = 0;
  let m;
  while ((m = re.exec(src))) {
    if (m.index > last) pushParsedText(nodes, src.slice(last, m.index));
    const def = defForInclude(m[1]);
    if (def?.inline) {
      nodes.push(includeNode(def, m[2], m[0]));
    } else {
      pushParsedText(nodes, m[0]);
    }
    last = m.index + m[0].length;
  }
  if (last < src.length) pushParsedText(nodes, src.slice(last));
  return nodes.filter((n) => n.type !== "text" || n.text !== "");
}

function stripOuterBlankLines(chunk) {
  return String(chunk || "").replace(/^\n+|\n+$/g, "");
}

function listItem(text) {
  return {
    type: "listItem",
    content: [{ type: "paragraph", content: paragraphNodes(text) }],
  };
}

function pushPlainChunk(content, text) {
  const raw = stripOuterBlankLines(text);
  if (!raw) return;
  if (/^(?:---|\*\*\*|___)\s*$/.test(raw)) {
    content.push({ type: "horizontalRule" });
    return;
  }
  const lines = raw.split("\n");
  if (lines.every((l) => l.startsWith(">"))) {
    const inner = lines.map((l) => l.replace(/^>\s?/, "")).join("\n");
    const innerNodes = [];
    pushProseChunks(innerNodes, inner);
    content.push({
      type: "blockquote",
      content: innerNodes.length ? innerNodes : [{ type: "paragraph" }],
    });
    return;
  }
  const bullet = lines.map((l) => l.match(/^[-+*]\s+(.*)$/));
  if (bullet.every(Boolean)) {
    content.push({
      type: "bulletList",
      content: bullet.map((m) => listItem(m[1])),
    });
    return;
  }
  const ordered = lines.map((l) => l.match(/^\d+\.\s+(.*)$/));
  if (ordered.every(Boolean)) {
    content.push({
      type: "orderedList",
      content: ordered.map((m) => listItem(m[1])),
    });
    return;
  }
  const heading = raw.match(/^(#{1,6})\s+([\s\S]*)$/);
  if (heading && !raw.includes("\n") && raw.trim() === raw) {
    content.push({
      type: "heading",
      attrs: { level: heading[1].length },
      content: paragraphNodes(heading[2]),
    });
    return;
  }
  content.push({ type: "paragraph", content: paragraphNodes(raw) });
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

function markKey(mark) {
  if (!mark) return "";
  if (mark.type === "link") return `link:${mark.attrs?.href || ""}`;
  if (mark.type === "textStyle") return `color:${mark.attrs?.color || ""}`;
  return mark.type;
}

/** Stored order is outer mark first, the same order ProseMirror keeps. */
function outerMarks(marks) {
  return (marks || []).filter((mark) => mark && mark.type !== "code");
}

function openDelim(mark) {
  switch (mark.type) {
    case "bold":
      return "**";
    case "italic":
      return "_";
    case "strike":
      return "~~";
    case "link":
      return "[";
    case "textStyle":
      return `<span style="color:${mark.attrs?.color || ""}">`;
    default:
      return "";
  }
}

function closeDelim(mark) {
  switch (mark.type) {
    case "bold":
      return "**";
    case "italic":
      return "_";
    case "strike":
      return "~~";
    case "link":
      return `](${mark.attrs?.href || ""})`;
    case "textStyle":
      return "</span>";
    default:
      return "";
  }
}

/** Spaces at the edge of a mark sit outside the delimiter, so `_hello _` reloads as italic. */
function trimMarkWhitespace(chars) {
  const keys = new Set();
  for (const item of chars) {
    for (const mark of item.marks) keys.add(markKey(mark));
  }
  for (const key of keys) {
    let i = 0;
    while (i < chars.length) {
      const has = (index) => chars[index].marks.some((mark) => markKey(mark) === key);
      if (!has(i)) {
        i += 1;
        continue;
      }
      let j = i;
      while (j < chars.length && has(j)) j += 1;
      let start = i;
      let end = j;
      while (start < end && /\s/.test(chars[start].ch)) {
        chars[start].marks = chars[start].marks.filter((mark) => markKey(mark) !== key);
        start += 1;
      }
      while (end > start && /\s/.test(chars[end - 1].ch)) {
        chars[end - 1].marks = chars[end - 1].marks.filter((mark) => markKey(mark) !== key);
        end -= 1;
      }
      i = j;
    }
  }
}

function serializeTextChars(chars) {
  trimMarkWhitespace(chars);
  let out = "";
  let active = [];
  for (const item of chars) {
    const next = item.marks;
    let shared = 0;
    while (
      shared < active.length &&
      shared < next.length &&
      markKey(active[shared]) === markKey(next[shared])
    ) {
      shared += 1;
    }
    for (let j = active.length - 1; j >= shared; j -= 1) out += closeDelim(active[j]);
    for (let j = shared; j < next.length; j += 1) out += openDelim(next[j]);
    active = next;
    out += item.ch;
  }
  for (let j = active.length - 1; j >= 0; j -= 1) out += closeDelim(active[j]);
  return out;
}

function inlineToMd(nodes) {
  let out = "";
  let chars = [];
  const flush = () => {
    if (!chars.length) return;
    out += serializeTextChars(chars);
    chars = [];
  };
  for (const node of nodes || []) {
    if (node.type === "text") {
      const marks = node.marks || [];
      if (marks.some((mark) => mark.type === "code")) {
        flush();
        out += `\`${node.text || ""}\``;
        continue;
      }
      const ordered = outerMarks(marks);
      for (const ch of node.text || "") {
        chars.push({
          ch,
          marks: ordered.map((mark) => ({ type: mark.type, attrs: mark.attrs })),
        });
      }
      continue;
    }
    flush();
    if (node.type === "hardBreak") {
      out += "  \n";
      continue;
    }
    const def = INCLUDE_DEFS.find((d) => d.name === node.type);
    if (def) out += includeMarkdown(def, node.attrs || {});
  }
  flush();
  return out;
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
        case "blockquote": {
          const inner = nodesToMarkdown(node.content || []).replace(/\n+$/, "");
          const quoted = inner
            .split("\n")
            .map((l) => (l.length ? `> ${l}` : ">"))
            .join("\n");
          return `${quoted}\n\n`;
        }
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
