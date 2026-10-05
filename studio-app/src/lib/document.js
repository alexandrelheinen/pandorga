/**
 * Front matter + body serialization helpers.
 */

import yaml from "js-yaml";

export function splitDocument(raw) {
  const text = String(raw || "");
  if (!text.startsWith("---")) {
    return { fmLines: [], fm: {}, body: text, hasFm: false };
  }
  const end = text.indexOf("\n---", 3);
  if (end < 0) return { fmLines: [], fm: {}, body: text, hasFm: false };
  const rawFm = text.slice(4, end).replace(/^\r?\n/, "");
  const afterClose = text.slice(end + 4);
  const blankAfterFm = /^\r?\n\r?\n/.test(afterClose);
  const body = afterClose.replace(/^(?:\r?\n)+/, "");
  const fmLines = rawFm.split(/\r?\n/);
  const fm = parseFrontMatter(rawFm);
  return { fmLines, fm, body, hasFm: true, rawFm, blankAfterFm };
}

function parseFrontMatter(rawFm) {
  try {
    const doc = yaml.load(rawFm, { schema: yaml.JSON_SCHEMA });
    if (doc && typeof doc === "object" && !Array.isArray(doc)) return doc;
  } catch {
    /* fall through to the line parser */
  }
  const fm = {};
  for (const line of String(rawFm || "").split(/\r?\n/)) {
    const m = line.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (!m) continue;
    let v = m[2];
    if (v === "true") v = true;
    else if (v === "false") v = false;
    else if (
      (v.startsWith('"') && v.endsWith('"')) ||
      (v.startsWith("'") && v.endsWith("'"))
    ) {
      v = v.slice(1, -1);
    }
    fm[m[1]] = v;
  }
  return fm;
}

function yamlScalar(value) {
  if (value === true || value === false) return String(value);
  if (typeof value === "number") return String(value);
  if (value == null) return '""';
  const s = String(value);
  if (s === "") return '""';
  if (/^(true|false|null|yes|no|~)$/i.test(s)) return JSON.stringify(s);
  if (/[:#&*!|>%@`]/.test(s) || /^[\s\-?]|:\s|\s$/.test(s) || /[\n"']/.test(s)) {
    return JSON.stringify(s);
  }
  return s;
}

function isEmptyFm(value) {
  if (value === "" || value == null) return true;
  if (Array.isArray(value) && value.length === 0) return true;
  return false;
}

function sameFmValue(a, b) {
  return JSON.stringify(a) === JSON.stringify(b);
}

function topLevelSpans(rawFm) {
  const lines = String(rawFm || "").replace(/\r\n/g, "\n").replace(/\n$/, "").split("\n");
  const spans = [];
  let i = 0;
  while (i < lines.length) {
    if (lines[i].trim() === "") {
      i++;
      continue;
    }
    const m = lines[i].match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (!m) {
      i++;
      continue;
    }
    const start = i;
    i++;
    while (i < lines.length) {
      const nxt = lines[i];
      if (nxt === "") {
        const after = lines[i + 1];
        if (after == null || /^[A-Za-z0-9_]+:\s*/.test(after)) break;
        i++;
        continue;
      }
      if (/^\s/.test(nxt)) {
        i++;
        continue;
      }
      break;
    }
    spans.push({ key: m[1], lines: lines.slice(start, i) });
  }
  return spans;
}

function formatKeyLines(key, value) {
  if (Array.isArray(value) && value.every((v) => v == null || typeof v !== "object")) {
    return [`${key}:`, ...value.map((v) => `  - ${yamlScalar(v)}`)];
  }
  if (value && typeof value === "object") {
    const dumped = yaml.dump(
      { [key]: value },
      { schema: yaml.JSON_SCHEMA, lineWidth: -1, noRefs: true }
    );
    return dumped.replace(/\n$/, "").split("\n");
  }
  return [`${key}: ${yamlScalar(value)}`];
}

function frontMatterChanged(original, fields) {
  const next = { ...original };
  for (const [key, val] of Object.entries(fields || {})) {
    if (isEmptyFm(val)) {
      if (!isEmptyFm(original[key])) delete next[key];
    } else {
      next[key] = val;
    }
  }
  const keys = new Set([...Object.keys(original), ...Object.keys(next)]);
  for (const key of keys) {
    if (!sameFmValue(original[key], next[key])) return true;
  }
  return false;
}

function rebuildFrontMatter(rawFm, fields) {
  const original = parseFrontMatter(rawFm);
  const next = { ...original };
  for (const [key, val] of Object.entries(fields || {})) {
    if (isEmptyFm(val)) {
      if (!isEmptyFm(original[key])) delete next[key];
    } else {
      next[key] = val;
    }
  }
  const originalKeys = Object.keys(original);
  const nextKeys = Object.keys(next);
  const unchanged =
    originalKeys.length === nextKeys.length &&
    nextKeys.every((key) => sameFmValue(original[key], next[key]));
  if (unchanged) return String(rawFm || "").replace(/\n$/, "");

  const spans = topLevelSpans(rawFm);
  const used = new Set();
  const out = [];
  for (const span of spans) {
    if (!Object.prototype.hasOwnProperty.call(next, span.key)) continue;
    used.add(span.key);
    if (sameFmValue(original[span.key], next[span.key])) out.push(...span.lines);
    else out.push(...formatKeyLines(span.key, next[span.key]));
  }
  for (const [key, val] of Object.entries(next)) {
    if (used.has(key)) continue;
    out.push(...formatKeyLines(key, val));
  }
  return out.join("\n");
}

/**
 * Rebuild file content from original FM lines, overlaying edited scalar fields
 * and replacing the body. Preserves unknown YAML structure where possible.
 */
export function rebuildDocument(originalRaw, { fields, body, format }) {
  if (format === "raw") {
    return body.endsWith("\n") ? body : body + "\n";
  }
  if (format === "yaml") {
    // YAML collections use dumpYaml / structured editors in main.js — not this path.
    return body.endsWith("\n") ? body : body + "\n";
  }

  const split = splitDocument(originalRaw);
  const { rawFm, hasFm, blankAfterFm } = split;
  const bodyNorm = String(body || "").replace(/^(?:\r?\n)+/, "");
  if (
    hasFm &&
    !frontMatterChanged(split.fm, fields) &&
    bodyNorm === String(split.body || "").replace(/^(?:\r?\n)+/, "")
  ) {
    return originalRaw;
  }
  const out = ["---"];
  if (hasFm) {
    const fmText = rebuildFrontMatter(rawFm, fields);
    if (fmText) out.push(fmText);
  } else {
    for (const [key, val] of Object.entries(fields || {})) {
      if (isEmptyFm(val)) continue;
      out.push(...formatKeyLines(key, val));
    }
  }
  out.push("---");
  const bodyText = String(body || "").replace(/^(?:\r?\n)+/, "");
  const withNl = bodyText.endsWith("\n") ? bodyText : bodyText + "\n";
  const gap = blankAfterFm ? "\n\n" : "\n";
  return out.join("\n") + gap + withNl;
}
