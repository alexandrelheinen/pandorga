import yaml from "js-yaml";

/** Load schema from the committed studio/schema.yml (same-origin in prod). */
export async function loadSchema() {
  for (const url of ["/studio/schema.yml", "./schema.yml"]) {
    try {
      const res = await fetch(url, { cache: "no-store" });
      if (res.ok) {
        const text = await res.text();
        return normalizeSchema(yaml.load(text));
      }
    } catch {
      /* try next */
    }
  }
  throw new Error("Could not load studio/schema.yml");
}

function normalizeSchema(raw) {
  const groups = [];
  const collections = [];

  function walk(nodes, groupLabel) {
    for (const entry of nodes || []) {
      if (!entry || typeof entry !== "object") continue;
      if (entry.type === "group") {
        groups.push({ name: entry.name, label: entry.label || entry.name });
        walk(entry.items, entry.label || entry.name);
      } else if (entry.type === "collection" || entry.type === "file") {
        const view = entry.view || {};
        collections.push({
          name: entry.name,
          label: entry.label || entry.name,
          group: groupLabel || "Content",
          type: entry.type,
          path: entry.path,
          format: entry.format || "yaml-frontmatter",
          filename: entry.filename,
          root_key: entry.root_key || null,
          description: entry.description || "",
          list: !!entry.list,
          fields: entry.fields || [],
          view,
          /** @type {string[] | null} */
          listMetaFields: Array.isArray(view.list_meta_fields)
            ? view.list_meta_fields.map(String)
            : null,
          operations: entry.operations || { delete: true },
        });
      }
    }
  }

  walk(raw?.content, null);
  return { media: raw?.media || {}, groups, collections, raw };
}

export function fieldIsBody(field) {
  const name = String(field?.name || "");
  return (
    field?.component === "markdown_body" ||
    name === "body" ||
    name.startsWith("body_") ||
    (name === "description" && field?.component === "markdown_body")
  );
}
