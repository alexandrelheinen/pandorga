/**
 * Modular search + sort + pagination for Studio collection entry lists.
 * Sort / page-size options are config-driven; render code only looks up by id.
 */

function cmpStr(a, b, dir = 1) {
  return (
    String(a || "").localeCompare(String(b || ""), undefined, {
      sensitivity: "base",
      numeric: true,
    }) * dir
  );
}

/** Empty dates sink to the end for both newest-first and oldest-first. */
function cmpDate(a, b, dir = 1) {
  const aa = String(a || "");
  const bb = String(b || "");
  if (!aa && !bb) return 0;
  if (!aa) return 1;
  if (!bb) return -1;
  return aa.localeCompare(bb) * dir;
}

/** @typedef {{ id: string, label: string, compare: (a: object, b: object) => number }} ListSortOption */

/** @type {ListSortOption[]} */
export const LIST_SORT_OPTIONS = [
  {
    id: "date-desc",
    label: "Date | newest first",
    compare: (a, b) =>
      cmpDate(a.date, b.date, -1) || cmpStr(a.title || a.name, b.title || b.name),
  },
  {
    id: "date-asc",
    label: "Date | oldest first",
    compare: (a, b) =>
      cmpDate(a.date, b.date, 1) || cmpStr(a.title || a.name, b.title || b.name),
  },
  {
    id: "title-asc",
    label: "Title | A–Z",
    compare: (a, b) => cmpStr(a.title || a.name, b.title || b.name, 1),
  },
  {
    id: "title-desc",
    label: "Title | Z–A",
    compare: (a, b) => cmpStr(a.title || a.name, b.title || b.name, -1),
  },
  {
    id: "path-asc",
    label: "Path | A–Z",
    compare: (a, b) => cmpStr(a.path || a.name, b.path || b.name, 1),
  },
  {
    id: "path-desc",
    label: "Path | Z–A",
    compare: (a, b) => cmpStr(a.path || a.name, b.path || b.name, -1),
  },
  {
    id: "key-asc",
    label: "Key | A–Z",
    compare: (a, b) => cmpStr(a.key || a.name, b.key || b.name, 1),
  },
];

export const DEFAULT_SORT_ID = "date-desc";

/** @typedef {{ id: string, label: string, size: number | null }} ListPageSizeOption */

/** `size: null` means ALL (no slice). */
export const LIST_PAGE_SIZE_OPTIONS = [
  { id: "10", label: "10", size: 10 },
  { id: "20", label: "20", size: 20 },
  { id: "30", label: "30", size: 30 },
  { id: "all", label: "ALL", size: null },
];

export const DEFAULT_PAGE_SIZE_ID = "10";

const LS_SORT_PREFIX = "studio-list-sort:";
const LS_PAGE_SIZE_PREFIX = "studio-list-page-size:";

export function sortOptionById(id) {
  return LIST_SORT_OPTIONS.find((o) => o.id === id) || LIST_SORT_OPTIONS[0];
}

export function pageSizeOptionById(id) {
  return (
    LIST_PAGE_SIZE_OPTIONS.find((o) => o.id === id) || LIST_PAGE_SIZE_OPTIONS[0]
  );
}

/** Normalize peeked tags (array, legacy string, or absent) to a string list. */
export function itemTags(item) {
  const raw = item?.tags;
  if (Array.isArray(raw)) {
    return raw.map((t) => String(t == null ? "" : t).trim()).filter(Boolean);
  }
  if (typeof raw === "string" && raw.trim()) return [raw.trim()];
  return [];
}

export function filterItems(items, query) {
  const q = String(query || "").trim().toLowerCase();
  if (!q) return items.slice();
  return items.filter((item) => {
    const hay = [
      item.title,
      item.name,
      item.key,
      item.path,
      item.date,
      itemTags(item).join(" "),
    ]
      .filter(Boolean)
      .join("\n")
      .toLowerCase();
    return hay.includes(q);
  });
}

export function filterItemsByTag(items, tag) {
  const tagQ = String(tag || "").trim().toLowerCase();
  if (!tagQ) return items.slice();
  return items.filter((item) =>
    itemTags(item).some((t) => t.toLowerCase() === tagQ)
  );
}

/** Distinct tags across items, sorted case-insensitively. */
export function collectDistinctTags(items) {
  const seen = new Map();
  for (const item of items || []) {
    for (const tag of itemTags(item)) {
      const key = tag.toLowerCase();
      if (!seen.has(key)) seen.set(key, tag);
    }
  }
  return [...seen.values()].sort((a, b) =>
    a.localeCompare(b, undefined, { sensitivity: "base" })
  );
}

export function applyListControls(
  items,
  { query = "", sortId = DEFAULT_SORT_ID, tag = "" } = {}
) {
  const filtered = filterItemsByTag(filterItems(items, query), tag);
  const opt = sortOptionById(sortId);
  return filtered.sort((a, b) => opt.compare(a, b));
}

/**
 * Slice a filtered+sorted list into a page.
 * @returns {{ items: object[], page: number, pageCount: number, pageSize: number | null, total: number, from: number, to: number }}
 */
export function paginateItems(
  items,
  { pageSizeId = DEFAULT_PAGE_SIZE_ID, page = 1 } = {}
) {
  const opt = pageSizeOptionById(pageSizeId);
  const total = items.length;
  const size = opt.size;

  if (size == null || size <= 0) {
    return {
      items: items.slice(),
      page: 1,
      pageCount: 1,
      pageSize: null,
      total,
      from: total ? 1 : 0,
      to: total,
    };
  }

  const pageCount = Math.max(1, Math.ceil(total / size));
  const safePage = Math.min(Math.max(1, Number(page) || 1), pageCount);
  const start = (safePage - 1) * size;
  const slice = items.slice(start, start + size);
  return {
    items: slice,
    page: safePage,
    pageCount,
    pageSize: size,
    total,
    from: total ? start + 1 : 0,
    to: start + slice.length,
  };
}

export function loadSortPreference(collectionName, fallback = DEFAULT_SORT_ID) {
  try {
    const v = localStorage.getItem(LS_SORT_PREFIX + collectionName);
    if (v && LIST_SORT_OPTIONS.some((o) => o.id === v)) return v;
  } catch {
    /* private mode / blocked storage */
  }
  return fallback;
}

export function saveSortPreference(collectionName, sortId) {
  try {
    localStorage.setItem(LS_SORT_PREFIX + collectionName, sortId);
  } catch {
    /* ignore */
  }
}

export function loadPageSizePreference(
  collectionName,
  fallback = DEFAULT_PAGE_SIZE_ID
) {
  try {
    const v = localStorage.getItem(LS_PAGE_SIZE_PREFIX + collectionName);
    if (v && LIST_PAGE_SIZE_OPTIONS.some((o) => o.id === v)) return v;
  } catch {
    /* private mode / blocked storage */
  }
  return fallback;
}

export function savePageSizePreference(collectionName, pageSizeId) {
  try {
    localStorage.setItem(LS_PAGE_SIZE_PREFIX + collectionName, pageSizeId);
  } catch {
    /* ignore */
  }
}

/**
 * Default ledger-meta field lists when schema view.list_meta_fields is absent.
 * Values are tree-item keys (peekMeta / yaml-only listing). Missing values skip.
 * Filename (basename + ext) is always appended by formatEntryListMeta — do not list it here.
 */
export const DEFAULT_LIST_META_FIELDS = {
  posts: ["date"],
  articles: ["date"],
  resources: ["category", "type", "language"],
  bibliography: ["key"],
  products: ["company", "start_date", "end_date"],
  projects: ["status", "start_date", "end_date"],
  jobs: ["company", "engagement", "start", "end"],
};

/** Fields that mean "filename" — reserved; always forced as the last segment. */
const FILENAME_FIELD_ALIASES = new Set(["name", "filename"]);

function basenameFromPath(path) {
  const parts = String(path || "")
    .split("/")
    .filter(Boolean);
  return parts.length ? parts[parts.length - 1] : "";
}

function formatMetaFieldValue(field, item) {
  if (field === "path") {
    const p = String(item.path || "")
      .split("/")
      .filter(Boolean)
      .join(" | ");
    return p || "";
  }
  const raw = item?.[field];
  if (raw == null) return "";
  if (Array.isArray(raw)) {
    return raw
      .map((v) => String(v == null ? "" : v).trim())
      .filter(Boolean)
      .join(", ");
  }
  return String(raw).trim();
}

/**
 * Resolve configured list-meta fields for a collection.
 * @param {{ name?: string, listMetaFields?: string[] | null } | null | undefined} collection
 * @returns {string[]}
 */
export function listMetaFieldsFor(collection) {
  if (Array.isArray(collection?.listMetaFields) && collection.listMetaFields.length) {
    return collection.listMetaFields.map(String);
  }
  const name = collection?.name;
  if (name && DEFAULT_LIST_META_FIELDS[name]) {
    return DEFAULT_LIST_META_FIELDS[name].slice();
  }
  return [];
}

/**
 * Build the ledger-meta line: configured fields joined by ` | `, filename always last.
 * Skips empty/missing fields. Does not invent data.
 * @param {object} item tree list item
 * @param {{ name?: string, listMetaFields?: string[] | null } | string[] | null | undefined} collectionOrFields
 */
export function formatEntryListMeta(item, collectionOrFields) {
  const fields = Array.isArray(collectionOrFields)
    ? collectionOrFields.map(String)
    : listMetaFieldsFor(collectionOrFields);

  const parts = [];
  for (const field of fields) {
    if (FILENAME_FIELD_ALIASES.has(field)) continue;
    const value = formatMetaFieldValue(field, item);
    if (value) parts.push(value);
  }

  const filename =
    String(item?.name || "").trim() || basenameFromPath(item?.path);
  if (filename && parts[parts.length - 1] !== filename) {
    parts.push(filename);
  }
  return parts.join(" | ");
}
