import yaml from "js-yaml";

/** js-yaml dump options shared by Studio YAML saves. */
export const YAML_DUMP_OPTS = {
  lineWidth: 100,
  noRefs: true,
  sortKeys: false,
};

/**
 * How a schema collection should be edited in Studio.
 * @returns {"list"|"map"|"source"|null}
 *   - list: root is a YAML sequence of objects (Profile contacts/education/…)
 *   - map: root (or root_key subtree) is an object with schema fields
 *   - source: free-form YAML — monospace editor only
 *   - null: not a YAML collection
 */
export function yamlEditKind(collection) {
  if (!collection || collection.format !== "yaml") return null;
  if (collection.list) return "list";
  if (collection.root_key) return "map";
  if ((collection.fields || []).length) return "map";
  return "source";
}

export function dumpYaml(value) {
  const text = yaml.dump(value ?? null, YAML_DUMP_OPTS);
  return text.endsWith("\n") ? text : text + "\n";
}

export function loadYaml(content) {
  try {
    return yaml.load(content);
  } catch (err) {
    const error = new Error(err?.message || "Invalid YAML");
    error.cause = err;
    throw error;
  }
}

/** Build an empty list item from schema field defs (defaults when set). */
export function emptyItemFromFields(fields) {
  const item = {};
  for (const field of fields || []) {
    if (!field?.name || field.hidden) continue;
    if (Object.prototype.hasOwnProperty.call(field, "default")) {
      item[field.name] = structuredCloneSafe(field.default);
    } else if (field.list) {
      item[field.name] = [];
    } else if (field.type === "boolean") {
      item[field.name] = false;
    } else {
      item[field.name] = "";
    }
  }
  return item;
}

function structuredCloneSafe(value) {
  if (value == null || typeof value !== "object") return value;
  try {
    return structuredClone(value);
  } catch {
    return JSON.parse(JSON.stringify(value));
  }
}

/**
 * Drop empty optional scalars/arrays from a map before dump, keeping unknown keys.
 * Empty string / null / undefined / [] are omitted for known schema fields.
 */
export function pruneEmptyFields(doc, fields) {
  if (!doc || typeof doc !== "object" || Array.isArray(doc)) return doc;
  const known = new Set((fields || []).map((f) => f.name).filter(Boolean));
  const out = { ...doc };
  for (const key of Object.keys(out)) {
    if (!known.has(key)) continue;
    const val = out[key];
    if (val === "" || val == null) {
      delete out[key];
    } else if (Array.isArray(val) && val.length === 0) {
      delete out[key];
    }
  }
  return out;
}

/** Normalize a loaded YAML root into a list of plain objects. */
export function asObjectList(doc) {
  if (!Array.isArray(doc)) return [];
  return doc.map((item) =>
    item && typeof item === "object" && !Array.isArray(item) ? { ...item } : {}
  );
}

/** Normalize a loaded YAML root into a plain object map. */
export function asObjectMap(doc) {
  if (doc && typeof doc === "object" && !Array.isArray(doc)) return { ...doc };
  return {};
}
