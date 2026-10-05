/**
 * Studio API path guards. Spec: docs/features/studio.md (AC-STU path allowlist).
 */

const ALLOWED_PREFIXES = ["content/"];

const BLOCKED_SEGMENTS = new Set([
  ".git",
  ".github",
  "_plugins",
  "node_modules",
  "studio-app",
  "functions",
  ".env",
  "secrets",
]);

export function normalizeRepoPath(raw) {
  const path = String(raw || "")
    .replace(/\\/g, "/")
    .replace(/^\/+/, "")
    .replace(/\/+/g, "/");
  if (!path || path.includes("\0")) return null;
  if (path.split("/").some((seg) => seg === ".." || BLOCKED_SEGMENTS.has(seg))) {
    return null;
  }
  if (!ALLOWED_PREFIXES.some((prefix) => path === prefix.slice(0, -1) || path.startsWith(prefix))) {
    return null;
  }
  return path;
}

export function collectionDir(name, schema) {
  const found = findEntry(schema?.content, name);
  return found?.path || null;
}

function findEntry(nodes, name) {
  for (const entry of nodes || []) {
    if (!entry || typeof entry !== "object") continue;
    if (entry.type === "group") {
      const nested = findEntry(entry.items, name);
      if (nested) return nested;
    } else if (entry.name === name) {
      return entry;
    }
  }
  return null;
}

export function listSchemaCollections(schema) {
  const out = [];
  walk(schema?.content, out);
  return out;
}

function walk(nodes, out) {
  for (const entry of nodes || []) {
    if (!entry || typeof entry !== "object") continue;
    if (entry.type === "group") {
      walk(entry.items, out);
    } else if (entry.type === "collection" || entry.type === "file") {
      out.push({
        name: entry.name,
        label: entry.label || entry.name,
        type: entry.type,
        path: entry.path,
        format: entry.format || "yaml-frontmatter",
        filename: entry.filename,
        fields: entry.fields || [],
        view: entry.view || {},
        operations: entry.operations || {},
      });
    }
  }
}
