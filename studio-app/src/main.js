import "./styles/studio.css";
import { loadSchema, fieldIsBody } from "./lib/schema.js";
import { studioApi, setTokenGetter } from "./api/client.js";
import { splitDocument, rebuildDocument } from "./lib/document.js";
import { createBodyEditor, INCLUDE_DEFS } from "./editor/body-editor.js";
import { roundTripMarkdown } from "./editor/liquid-core.js";
import { renderPreview } from "./preview/render.js";
import {
  LIST_SORT_OPTIONS,
  LIST_PAGE_SIZE_OPTIONS,
  DEFAULT_SORT_ID,
  DEFAULT_PAGE_SIZE_ID,
  applyListControls,
  paginateItems,
  loadSortPreference,
  saveSortPreference,
  loadPageSizePreference,
  savePageSizePreference,
  formatEntryListMeta,
} from "./lib/list-controls.js";
import {
  yamlEditKind,
  dumpYaml,
  loadYaml,
  emptyItemFromFields,
  pruneEmptyFields,
  asObjectList,
  asObjectMap,
} from "./lib/yaml-doc.js";
import { renderMediaPane, openMediaDir, mediaRootFromSchema } from "./media/browser.js";

const PUBLISHABLE_KEY =
  import.meta.env.VITE_CLERK_PUBLISHABLE_KEY ||
  window.__STUDIO_CLERK_KEY__ ||
  "";

/** Studio lives at /studio/; Clerk's component fallbackRedirectUrl defaults to `/`. */
const STUDIO_PATH = "/studio/";

/**
 * Keep in sync with `_config.yml` → `content_api_base_url` and `_redirects` `/media/*`.
 * Studio list thumbs must hit R2 directly: Vite/local has no Pages `_redirects`, and
 * same-origin `/media/…` is otherwise a dead path in the SPA.
 */
const MEDIA_BASE = import.meta.env.VITE_CONTENT_API_BASE_URL || "";

const CLERK_REDIRECTS = {
  forceRedirectUrl: STUDIO_PATH,
  fallbackRedirectUrl: STUDIO_PATH,
  signInForceRedirectUrl: STUDIO_PATH,
  signInFallbackRedirectUrl: STUDIO_PATH,
  signUpForceRedirectUrl: STUDIO_PATH,
  signUpFallbackRedirectUrl: STUDIO_PATH,
};

/** Decode Frontend API host from a Clerk publishable key (`pk_test_` / `pk_live_`). */
function frontendApiHostFromKey(key) {
  const raw = String(key || "").replace(/^pk_(test|live)_/, "");
  if (!raw) return "";
  try {
    const pad = "=".repeat((4 - (raw.length % 4)) % 4);
    const b64 = (raw + pad).replace(/-/g, "+").replace(/_/g, "/");
    return atob(b64).replace(/\$$/, "").trim();
  } catch {
    return "";
  }
}

/**
 * Load Clerk from the instance CDN (clerk-js@6) with UI components.
 * Clerk dashboard “Quick copy” loads `@clerk/ui` first, then `clerk-js` with
 * data-clerk-publishable-key. Without the UI script, mountSignIn throws
 * “Clerk was not loaded with Ui components”. Do not `new` window.Clerk —
 * the browser build exposes a ready instance.
 */
function loadScript(src, attrs = {}) {
  return new Promise((resolve, reject) => {
    const existing = document.querySelector(`script[src="${src}"]`);
    if (existing) {
      if (existing.dataset.loaded === "1") return resolve();
      existing.addEventListener("load", () => resolve(), { once: true });
      existing.addEventListener("error", () => reject(new Error(`Failed to load ${src}`)), {
        once: true,
      });
      return;
    }
    const s = document.createElement("script");
    s.src = src;
    s.async = true;
    s.defer = true;
    s.crossOrigin = "anonymous";
    for (const [k, v] of Object.entries(attrs)) {
      if (k === "dataset" && v && typeof v === "object") {
        for (const [dk, dv] of Object.entries(v)) s.dataset[dk] = dv;
      } else if (v != null) s.setAttribute(k, v);
    }
    s.onload = () => {
      s.dataset.loaded = "1";
      resolve();
    };
    s.onerror = () => reject(new Error(`Failed to load ${src}`));
    document.head.appendChild(s);
  });
}

async function loadClerkInstance(publishableKey) {
  if (window.Clerk && typeof window.Clerk.load === "function" && window.__internal_ClerkUICtor) {
    return window.Clerk;
  }
  const host =
    String(import.meta.env.VITE_CLERK_JWT_ISSUER || "")
      .replace(/^https?:\/\//, "")
      .replace(/\/$/, "") || frontendApiHostFromKey(publishableKey);
  if (!host) {
    throw new Error("Cannot resolve Clerk Frontend API host from publishable key");
  }
  const base = `https://${host}/npm`;
  // UI first (publishes window.__internal_ClerkUICtor), then clerk-js instance.
  await loadScript(`${base}/@clerk/ui@1/dist/ui.browser.js`);
  await loadScript(`${base}/@clerk/clerk-js@6/dist/clerk.browser.js`, {
    dataset: { clerkPublishableKey: publishableKey },
  });
  for (let i = 0; i < 80; i++) {
    const ready =
      window.Clerk &&
      typeof window.Clerk.load === "function" &&
      window.__internal_ClerkUICtor;
    if (ready) return window.Clerk;
    await new Promise((r) => setTimeout(r, 25));
  }
  throw new Error("Clerk / ClerkUI global missing after script load");
}

async function initClerk() {
  if (!PUBLISHABLE_KEY) {
    // Dev / preview without Clerk: rely on STUDIO_DEV_BYPASS on the Function.
    setTokenGetter(async () => "dev-bypass-token");
    return { dev: true };
  }
  const clerk = await loadClerkInstance(PUBLISHABLE_KEY);
  // v6: UICtor must be passed into load() or mountSignIn asserts components missing.
  // Pin redirects in code: dashboard Paths alone leave component fallback at `/`.
  await clerk.load({
    clerkUICtor: window.__internal_ClerkUICtor,
    ...CLERK_REDIRECTS,
  });
  setTokenGetter(async () => {
    if (!clerk.session) return null;
    return clerk.session.getToken();
  });
  return clerk;
}

const app = document.getElementById("app");

const state = {
  schema: null,
  session: null,
  collection: null,
  items: [],
  file: null,
  sha: null,
  fields: {},
  body: "",
  yamlDoc: null,
  /** Root YAML sequence when collection.list (Profile contacts/education/…). */
  yamlList: null,
  /** YAML editor chrome: structured fields vs monospace source. */
  yamlUiMode: "structured",
  /** Markdown body chrome: visual | source | preview (preview is mobile-only tab). */
  bodyMode: "visual",
  /** Last Visual/Source mode before switching to the Preview tab. */
  lastEditorMode: "visual",
  /** Snapshot of last fetched / last saved entry for Discard. */
  baseline: null,
  dirty: false,
  /** True while a save request is in flight. Blocks a second tap. */
  saving: false,
  status: "",
  error: "",
  /** API `error` code, when the failure came from the Studio function. */
  errorCode: "",
  /** Compact fetch/error detail for the list/editor (status + payload). */
  errorDetail: "",
  listLoading: false,
  fileLoading: false,
  previewHtml: "",
  bodyEditor: null,
  insertMenuOpen: false,
  /** Soft hint under AI Proof when selection is missing. */
  aiProofHint: "",
  /** In-flight Correct/Refine on the current body selection. */
  aiProofBusy: false,
  /**
   * Body selection captured on Correct/Refine mousedown, before the click
   * takes focus off the editor and clears the live selection.
   */
  aiProofSelection: null,
  /** Open left-nav accordion groups (start empty = all folded). */
  navOpenGroups: new Set(),
  /** Mobile nav disclosure (≤960px); desktop left aside from 961px up. */
  navMenuOpen: false,
  /** Theme menu (light / dark / system) in the icon toolbar. */
  themeMenuOpen: false,
  /**
   * Content publish indicator (local Export animation or production Actions).
   * state: idle | syncing | awaiting_run | running | ok | error | stalled | unconfigured
   */
  pipeline: {
    state: "idle",
    sha: "",
    runUrl: "",
    message: "",
    pollGen: 0,
  },
  /** Local Export button in flight. */
  reexporting: false,
  /** Per-collection list query (session memory). */
  listQueryByCollection: Object.create(null),
  /** Per-collection sort id (session + localStorage). */
  listSortByCollection: Object.create(null),
  /** Per-collection page size id (session + localStorage). */
  listPageSizeByCollection: Object.create(null),
  /** Per-collection current page (1-based; session only). */
  listPageByCollection: Object.create(null),
  /** In-session nav entry counts keyed by collection name. */
  navCountByCollection: Object.create(null),
  /** Session tree cache: collection name → { items }. Avoids re-fetch on revisit. */
  treeCacheByCollection: Object.create(null),
  /** Bumped to drop stale idle prefetch work. */
  treePrefetchGen: 0,
  /** Editor front-matter accordion open state (null = choose from fields/dirty). */
  frontMatterOpen: null,
  /** Media library view (content/media tree). */
  mediaOpen: false,
  mediaPath: "content/media",
  mediaItems: [],
  mediaLoading: false,
  mediaBusy: false,
};

/** Material Symbol names for Liquid include Insert menu. */
const INCLUDE_ICONS = {
  figure: "image",
  cutIn: "transition_push",
  youtube: "smart_display",
  youtubeShort: "mobile_screen_share",
  video: "videocam",
  plotly: "analytics",
  xcite: "format_quote",
  cite: "bookmark",
  articleNote: "sticky_note_2",
  poem: "history_edu",
};

const GROUP_ICONS = {
  Writing: "edit_note",
  References: "menu_book",
  Portfolio: "work",
  Media: "photo_library",
  Pages: "description",
  "CV Summary": "badge",
  Presentation: "campaign",
  Profile: "person",
};

const TEXT_COLORS = [
  { label: "Default", value: "" },
  { label: "Primary", value: "var(--primary)" },
  { label: "Secondary", value: "var(--secondary)" },
  { label: "Tertiary", value: "var(--tertiary)" },
  { label: "Muted", value: "var(--on-surface-variant)" },
  { label: "Error", value: "var(--error)" },
];

/** Short hover hints for left-nav section groups. */
const GROUP_HINTS = {
  Writing: "Articles and Portuguese rascunhos",
  References: "Source cards and bibliography entries",
  Portfolio: "Products, projects, and CV jobs",
  Media: "Upload and browse content/media — cite /media/… in includes",
  Pages: "Listing page headers and furniture copy",
  "CV Summary": "Public and PDF CV summary variants",
  Presentation: "Home catch phrase and CV side notes",
  Profile: "Contacts, education, languages, and skills",
};

function formatPath(path) {
  return String(path || "")
    .split("/")
    .filter(Boolean)
    .join(" | ");
}

function groupHint(label) {
  return GROUP_HINTS[label] || `Browse ${label} collections`;
}

function navGroupDomId(group) {
  return (
    "nav-group-" +
    String(group)
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-|-$/g, "")
  );
}

/** Expand/collapse a left-nav group without rebuilding the shell (keeps scroll). */
function toggleNavGroup(group) {
  const open = !state.navOpenGroups.has(group);
  if (open) state.navOpenGroups.add(group);
  else state.navOpenGroups.delete(group);

  const items = document.getElementById(navGroupDomId(group));
  if (!items) return;
  items.hidden = !open;
  const toggle = items
    .closest(".studio-nav-group")
    ?.querySelector(".studio-nav-group-toggle");
  if (toggle) {
    toggle.setAttribute("aria-expanded", open ? "true" : "false");
    const icon = toggle.querySelector(".material-symbols-outlined");
    if (icon) icon.textContent = open ? "expand_more" : "chevron_right";
  }
}

function collectionHint(col) {
  const cleaned = sanitizeUiCopy(col.description);
  if (cleaned) return cleaned;
  const where = formatPath(col.path) || col.name;
  if (col.type === "file") return `Open ${col.label} | ${where}`;
  return `List entries in ${col.label} | ${where}`;
}

/**
 * Strip developer-contract prose from schema descriptions before UI display.
 * Keeps short editorial hints; drops filename rules, TipTap/Liquid notes, etc.
 */
function sanitizeUiCopy(raw) {
  let text = String(raw || "").trim();
  if (!text) return "";
  const dropPatterns = [
    /\s*The filename uses Key as YYYY-MM-DD-key[^.]*\./gi,
    /\s*Also the filename stem:[^.]*\./gi,
    /\s*Also the filename:[^.]*\./gi,
    /\s*Must match the YYYY-MM-DD in the filename[^.]*\./gi,
    /\s*;?\s*must match the YYYY-MM-DD in the filename\./gi,
    /\s*The Updated date is read from Git, never set here\./gi,
    /\s*ASCII kebab-case\./gi,
    /\s*\(44 characters total for the key segment is a good ceiling\)\.?/gi,
    /Metadata-first forms[^.]*\./gi,
    /TipTap with Liquid blocks[^.]*\./gi,
    /preview via content-runtime contract\.?/gi,
    /Paste Liquid \{%\s*include\s*%\} markers[^.]*\./gi,
    /Do not use rich-text:[^.]*\./gi,
    /its Editor mode rewrites URLs inside includes\.?/gi,
    /Markdown source \(code editor\)\.?/gi,
  ];
  for (const re of dropPatterns) text = text.replace(re, "");
  text = text.replace(/\s{2,}/g, " ").replace(/\s+\./g, ".").trim();
  if (/filename|YYYY-MM-DD-key|content-runtime|autolink|TipTap/i.test(text)) {
    return "";
  }
  return text;
}

function fieldHint(field) {
  return sanitizeUiCopy(field?.description);
}

function captureError(err) {
  const message = String(err?.message || err || "Request failed");
  const parts = [];
  if (err?.status) parts.push(`HTTP ${err.status}`);
  const detail = err?.data?.detail;
  if (detail) parts.push(String(detail));
  else if (err?.data && typeof err.data === "object") {
    try {
      parts.push(JSON.stringify(err.data, null, 2));
    } catch {
      /* ignore */
    }
  } else if (err?.stack && !String(err.stack).includes(message)) {
    parts.push(String(err.stack).split("\n").slice(0, 6).join("\n"));
  }
  state.error = message;
  state.errorCode = String(err?.code || err?.data?.error || "");
  state.errorDetail = parts.join("\n").trim();
  state.status = "";
}

function clearError() {
  state.error = "";
  state.errorCode = "";
  state.errorDetail = "";
}

function currentNavLabel() {
  if (state.mediaOpen) return "Media";
  if (state.collection?.label) return state.collection.label;
  return "Home";
}

function closeNavMenu() {
  state.navMenuOpen = false;
}

function closeStudioMenus() {
  closeNavMenu();
  closeThemeMenu();
}

function goHome() {
  destroyBodyEditor();
  state.collection = null;
  state.file = null;
  state.baseline = null;
  state.items = [];
  state.yamlDoc = null;
  state.yamlList = null;
  state.listLoading = false;
  state.fileLoading = false;
  state.dirty = false;
  state.insertMenuOpen = false;
  state.mediaOpen = false;
  state.mediaItems = [];
  state.mediaLoading = false;
  state.mediaBusy = false;
  closeNavMenu();
  clearError();
  state.status = state.session?.email || state.session?.userId || "";
  renderShell();
  scheduleTreePrefetch();
}

function mediaOpts() {
  return {
    api: studioApi,
    state,
    el,
    materialIcon,
    resolveMediaUrl: resolveThumbnailUrl,
    render: () => renderShell(),
    captureError,
    clearError,
    goHome,
    onCommitted: (commitSha) => armPipelineWatch(commitSha),
  };
}

async function openMediaLibrary(dirPath) {
  destroyBodyEditor();
  state.collection = null;
  state.file = null;
  state.baseline = null;
  state.items = [];
  state.insertMenuOpen = false;
  state.dirty = false;
  state.mediaOpen = true;
  state.navOpenGroups.add("Media");
  closeNavMenu();
  const root = mediaRootFromSchema(state.schema);
  await openMediaDir(dirPath || root, mediaOpts());
}

function materialIcon(name, extraClass = "") {
  return el("span", {
    className: "material-symbols-outlined" + (extraClass ? ` ${extraClass}` : ""),
    text: name,
    "aria-hidden": "true",
  });
}

/**
 * Studio mark — same theme swap as the public site stamp (base.css):
 * light page → pastel triad; dark page → production triad.
 * Inline SVG so data-theme CSS can paint fills (img + prefers-color-scheme cannot).
 */
function studioMark({ size = 40, label = "" } = {}) {
  const aria =
    label
      ? { role: "img", "aria-label": label }
      : { "aria-hidden": "true" };
  return el("span", {
    className: "studio-mark",
    ...aria,
    html:
      `<svg class="studio-mark-svg" viewBox="0 0 32 32" width="${size}" height="${size}" focusable="false">` +
      `<polygon class="studio-mark-primary" points="16,1 24,5 13,14 2,17 2,9"/>` +
      `<polygon class="studio-mark-secondary" points="24,5 30,9 30,23 22,28 19,18 13,14"/>` +
      `<polygon class="studio-mark-tertiary" points="2,17 13,14 19,18 22,28 16,31 2,23"/>` +
      `<polygon class="studio-mark-frame" points="16,1 30,9 30,23 16,31 2,23 2,9"/>` +
      `</svg>`,
  });
}

function entryHint(item) {
  const title = item.title || item.name || "Entry";
  const path = formatPath(item.path);
  return path ? `Open ${title} | ${path}` : `Open ${title}`;
}

function currentListQuery() {
  const name = state.collection?.name;
  if (!name) return "";
  return state.listQueryByCollection[name] || "";
}

function currentListSortId() {
  const name = state.collection?.name;
  if (!name) return DEFAULT_SORT_ID;
  if (state.listSortByCollection[name]) return state.listSortByCollection[name];
  const stored = loadSortPreference(name, DEFAULT_SORT_ID);
  state.listSortByCollection[name] = stored;
  return stored;
}

function setListSortId(sortId) {
  const name = state.collection?.name;
  if (!name) return;
  state.listSortByCollection[name] = sortId;
  saveSortPreference(name, sortId);
  resetListPage();
}

function currentListPageSizeId() {
  const name = state.collection?.name;
  if (!name) return DEFAULT_PAGE_SIZE_ID;
  if (state.listPageSizeByCollection[name]) {
    return state.listPageSizeByCollection[name];
  }
  const stored = loadPageSizePreference(name, DEFAULT_PAGE_SIZE_ID);
  state.listPageSizeByCollection[name] = stored;
  return stored;
}

function setListPageSizeId(pageSizeId) {
  const name = state.collection?.name;
  if (!name) return;
  state.listPageSizeByCollection[name] = pageSizeId;
  savePageSizePreference(name, pageSizeId);
  resetListPage();
}

function currentListPage() {
  const name = state.collection?.name;
  if (!name) return 1;
  return Math.max(1, Number(state.listPageByCollection[name]) || 1);
}

function setListPage(page) {
  const name = state.collection?.name;
  if (!name) return;
  state.listPageByCollection[name] = Math.max(1, Number(page) || 1);
}

function resetListPage() {
  const name = state.collection?.name;
  if (!name) return;
  state.listPageByCollection[name] = 1;
}

function rememberNavCount(col, count) {
  if (!col?.name) return;
  state.navCountByCollection[col.name] = Math.max(0, Number(count) || 0);
}

function rememberTree(col, items) {
  if (!col?.name) return;
  const list = Array.isArray(items) ? items : [];
  state.treeCacheByCollection[col.name] = { items: list };
  rememberNavCount(col, list.length);
}

function cachedTreeItems(col) {
  if (!col?.name) return null;
  const hit = state.treeCacheByCollection[col.name];
  return hit ? hit.items : null;
}

function invalidateTreeCache(colName) {
  if (!colName) {
    state.treeCacheByCollection = Object.create(null);
    return;
  }
  delete state.treeCacheByCollection[colName];
}

function folderCollections(schema = state.schema) {
  return (schema?.collections || []).filter(
    (c) => c && c.type !== "file" && c.path
  );
}

/** Writing first, then the rest — fills nav counts users care about earliest. */
function prefetchCollectionOrder(cols) {
  return [...cols].sort((a, b) => {
    const pa = a.group === "Writing" ? 0 : 1;
    const pb = b.group === "Writing" ? 0 : 1;
    if (pa !== pb) return pa - pb;
    return String(a.label || a.name).localeCompare(String(b.label || b.name));
  });
}

function scheduleTreePrefetch() {
  const gen = ++state.treePrefetchGen;
  const run = () => {
    void prefetchTreesInIdle(gen);
  };
  if (typeof requestIdleCallback === "function") {
    requestIdleCallback(run, { timeout: 2500 });
  } else {
    setTimeout(run, 400);
  }
}

async function prefetchTreesInIdle(gen) {
  const pending = prefetchCollectionOrder(folderCollections()).filter(
    (c) => !state.treeCacheByCollection[c.name]
  );
  for (const col of pending) {
    if (gen !== state.treePrefetchGen) return;
    try {
      const data = await studioApi.tree(col.path);
      if (gen !== state.treePrefetchGen) return;
      // Keep a fresher selectCollection result if it won the race.
      if (!state.treeCacheByCollection[col.name]) {
        rememberTree(col, data.items || []);
        // Rebuild only when not mid-entry — avoids yanking the editor.
        if (!state.file) renderShell();
      }
    } catch {
      // Best-effort: leave the count absent until the user opens the list.
    }
    await new Promise((r) => setTimeout(r, 60));
  }
}

/** Resolve Studio list thumbnails to a loadable URL. */
function resolveThumbnailUrl(raw) {
  const value = String(raw || "").trim();
  if (!value) return "";
  if (/^https?:\/\//i.test(value)) return value;
  if (value.startsWith("/media/")) {
    return `${MEDIA_BASE.replace(/\/$/, "")}${value}`;
  }
  if (value.startsWith("media/")) {
    return `${MEDIA_BASE.replace(/\/$/, "")}/${value}`;
  }
  if (value.startsWith("/")) return value;
  return value;
}

function missingThumbPlaceholder() {
  return el("span", {
    className: "ledger-thumb placeholder",
    title: "No thumbnail",
    "aria-label": "No thumbnail",
  }, [
    el("span", {
      className: "material-symbols-outlined",
      text: "web_asset_off",
      "aria-hidden": "true",
    }),
  ]);
}

function thumbnailNode(item) {
  const src = resolveThumbnailUrl(item.thumbnail);
  if (!src) return missingThumbPlaceholder();
  const img = el("img", {
    className: "ledger-thumb",
    src,
    alt: "",
    loading: "lazy",
    referrerpolicy: "no-referrer",
  });
  img.addEventListener("error", () => {
    img.replaceWith(missingThumbPlaceholder());
  });
  return img;
}

function $(sel, root = document) {
  return root.querySelector(sel);
}

function el(tag, attrs = {}, children = []) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "className") node.className = v;
    else if (k === "text") node.textContent = v;
    else if (k === "html") node.innerHTML = v;
    else if (k === "htmlFor") node.htmlFor = v;
    else if (k.startsWith("on") && typeof v === "function") {
      node.addEventListener(k.slice(2).toLowerCase(), v);
    } else if (
      k === "checked" ||
      k === "selected" ||
      k === "disabled" ||
      k === "multiple" ||
      k === "open"
    ) {
      // IDL boolean props — setAttribute("checked","") is unreliable for toggles.
      node[k] = !!v;
    } else if (v === false || v == null) {
      /* skip */
    } else if (v === true) node.setAttribute(k, "");
    else node.setAttribute(k, v);
  }
  for (const child of [].concat(children)) {
    if (child == null || child === false) continue;
    node.append(child.nodeType ? child : document.createTextNode(String(child)));
  }
  return node;
}

const THEME_CHOICE_KEY = "studio-theme";
const THEME_MENU_ICONS = { light: "light_mode", dark: "dark_mode", system: "routine" };

function themeChoice() {
  const saved = localStorage.getItem(THEME_CHOICE_KEY);
  if (saved === "light" || saved === "dark" || saved === "system") return saved;
  return "system";
}

function resolvedTheme() {
  const choice = themeChoice();
  if (choice === "dark") return "dark";
  if (choice === "light") return "light";
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function setThemeChoice(choice) {
  localStorage.setItem(THEME_CHOICE_KEY, choice);
  applyResolvedTheme();
  syncThemeMenuUi();
}

function applyResolvedTheme() {
  document.documentElement.setAttribute("data-theme", resolvedTheme());
}

function initTheme() {
  applyResolvedTheme();
  const mq = window.matchMedia("(prefers-color-scheme: dark)");
  if (typeof mq.addEventListener === "function") {
    mq.addEventListener("change", () => {
      if (themeChoice() === "system") applyResolvedTheme();
    });
  }
}

function closeThemeMenu() {
  state.themeMenuOpen = false;
}

function syncThemeMenuUi() {
  const active = themeChoice();
  const icon = document.querySelector("[data-studio-theme-icon]");
  if (icon) icon.textContent = THEME_MENU_ICONS[active] || THEME_MENU_ICONS.system;
  for (const item of document.querySelectorAll("[data-theme-choice]")) {
    const choice = item.getAttribute("data-theme-choice");
    const selected = choice === active;
    item.setAttribute("aria-checked", selected ? "true" : "false");
    item.classList.toggle("is-selected", selected);
  }
  const btn = document.querySelector("[data-studio-action='theme-menu']");
  const menu = document.getElementById("studio-theme-menu");
  if (btn && menu) {
    btn.setAttribute("aria-expanded", state.themeMenuOpen ? "true" : "false");
    menu.hidden = !state.themeMenuOpen;
  }
}

function renderThemeMenu() {
  const choices = [
    { id: "light", label: "Light", icon: "light_mode" },
    { id: "dark", label: "Dark", icon: "dark_mode" },
    { id: "system", label: "System", icon: "routine" },
  ];
  const menu = el("div", {
    className: "studio-theme-menu-panel",
    id: "studio-theme-menu",
    role: "menu",
    "aria-label": "Choose color theme",
    hidden: !state.themeMenuOpen,
  }, choices.map((c) =>
    el("button", {
      className: "studio-theme-choice",
      type: "button",
      role: "menuitemradio",
      "data-theme-choice": c.id,
      "aria-checked": themeChoice() === c.id ? "true" : "false",
      onClick: (e) => {
        e.stopPropagation();
        setThemeChoice(c.id);
        state.themeMenuOpen = false;
        syncThemeMenuUi();
        const frame = $("#preview-frame");
        if (frame) void mountMermaidPreview(frame);
      },
    }, [
      materialIcon(c.icon),
      el("span", { text: c.label }),
    ])
  ));

  const btn = el("button", {
    className: "btn btn-tool",
    type: "button",
    title: "Theme",
    "aria-label": "Theme",
    "data-studio-action": "theme-menu",
    "aria-haspopup": "true",
    "aria-expanded": state.themeMenuOpen ? "true" : "false",
    "aria-controls": "studio-theme-menu",
    onClick: (e) => {
      e.stopPropagation();
      state.themeMenuOpen = !state.themeMenuOpen;
      syncThemeMenuUi();
    },
  }, [
    el("span", {
      className: "material-symbols-outlined",
      "data-studio-theme-icon": "true",
      text: THEME_MENU_ICONS[themeChoice()] || THEME_MENU_ICONS.system,
      "aria-hidden": "true",
    }),
    el("span", { className: "btn-label", text: "Theme" }),
  ]);

  return el("div", { className: "studio-theme-menu" }, [btn, menu]);
}

function isLocalDevHost() {
  const host = String(window.location.hostname || "");
  return host === "localhost" || host === "127.0.0.1" || host === "[::1]";
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function pipelineChipMeta(pipelineState) {
  switch (pipelineState) {
    case "syncing":
    case "running":
      return {
        label: "Exporting…",
        icon: "progress_activity",
        className: "pipeline-chip pipeline-running",
        spinning: true,
        title: "Content export is running",
      };
    case "awaiting_run":
      return {
        label: "Waiting…",
        icon: "schedule",
        className: "pipeline-chip pipeline-awaiting",
        spinning: false,
        title: "Waiting for the content pipeline run",
      };
    case "ok":
      return {
        label: "Live",
        icon: "check_circle",
        className: "pipeline-chip pipeline-ok",
        spinning: false,
        title: "Content pipeline succeeded for this commit",
      };
    case "error":
      return {
        label: "Failed",
        icon: "error",
        className: "pipeline-chip pipeline-error",
        spinning: false,
        title: state.pipeline.message || "Content pipeline failed",
      };
    case "stalled":
      return {
        label: "No run",
        icon: "hourglass_disabled",
        className: "pipeline-chip pipeline-stalled",
        spinning: false,
        title: "No pipeline run appeared for this commit yet",
      };
    case "unconfigured":
      return {
        label: "Pipeline",
        icon: "cloud_off",
        className: "pipeline-chip pipeline-idle",
        spinning: false,
        title:
          state.pipeline.message ||
          "Set pandorga.content.workflow in _config.yml (e.g. content-pipeline.yml)",
      };
    default:
      return {
        label: "Pipeline",
        icon: "cloud",
        className: "pipeline-chip pipeline-idle",
        spinning: false,
        title: "Content pipeline status",
      };
  }
}

function renderPipelineChip() {
  const meta = pipelineChipMeta(state.pipeline.state);
  const runUrl = state.pipeline.runUrl;
  const kids = [
    el("span", {
      className:
        "material-symbols-outlined" + (meta.spinning ? " studio-icon-spin" : ""),
      text: meta.icon,
      "aria-hidden": "true",
    }),
    el("span", { className: "btn-label", text: meta.label }),
  ];
  return el(
    "button",
    {
      className: `btn btn-tool ${meta.className}`,
      type: "button",
      title: meta.title,
      "aria-label": meta.label,
      role: "status",
      "data-studio-action": "pipeline-status",
      disabled: !runUrl,
      onClick: () => {
        if (!runUrl) return;
        try {
          window.open(runUrl, "_blank", "noopener,noreferrer");
        } catch {
          /* ignore */
        }
      },
    },
    kids
  );
}

function applyPipelinePayload(data) {
  state.pipeline.runUrl = data.run?.html_url || state.pipeline.runUrl || "";
  if (data.sha) state.pipeline.sha = String(data.sha).toLowerCase();
  state.pipeline.message = "";
  if (data.state === "unconfigured") {
    state.pipeline.state = "unconfigured";
    state.pipeline.message =
      data.message ||
      "Set pandorga.content.workflow in _config.yml (e.g. content-pipeline.yml)";
    return;
  }
  state.pipeline.state = data.state || "idle";
  if (data.state === "error") {
    state.pipeline.message =
      data.message || "Content pipeline failed for this commit.";
  }
}

/** Hydrate the always-visible chip from the latest workflow run (or a SHA). */
async function refreshPipelineStatus(sha = null) {
  if (isLocalDevHost()) return;
  try {
    const data = await studioApi.pipelineStatus(sha || null);
    applyPipelinePayload(data);
    renderShell();
  } catch (err) {
    state.pipeline.state = "error";
    state.pipeline.message = String(err.message || err);
    renderShell();
  }
}

/**
 * After a production Save, poll Actions for the content-pipeline run on this SHA.
 */
function armPipelineWatch(commitSha) {
  const sha = String(commitSha || "").trim().toLowerCase();
  if (!sha || isLocalDevHost()) return;
  const gen = ++state.pipeline.pollGen;
  state.pipeline.state = "awaiting_run";
  state.pipeline.sha = sha;
  state.pipeline.runUrl = "";
  state.pipeline.message = "";
  renderShell();
  void pollPipelineStatus(gen, sha);
}

async function pollPipelineStatus(gen, sha) {
  const started = Date.now();
  const STALL_MS = 10 * 60 * 1000;
  const MAX_MS = 30 * 60 * 1000;
  let softFails = 0;

  while (gen === state.pipeline.pollGen) {
    const elapsed = Date.now() - started;
    if (elapsed > MAX_MS) {
      if (state.pipeline.state === "running" || state.pipeline.state === "awaiting_run") {
        state.pipeline.state = "stalled";
        state.pipeline.message = "Timed out waiting for the content pipeline.";
        renderShell();
      }
      return;
    }

    try {
      const data = await studioApi.pipelineStatus(sha);
      if (gen !== state.pipeline.pollGen) return;
      softFails = 0;
      applyPipelinePayload(data);

      if (data.state === "unconfigured" || data.state === "ok" || data.state === "error") {
        renderShell();
        return;
      }
      if (data.state === "awaiting_run" && elapsed > STALL_MS) {
        state.pipeline.state = "stalled";
        renderShell();
        return;
      }
      renderShell();
    } catch (err) {
      if (gen !== state.pipeline.pollGen) return;
      softFails += 1;
      const code = err?.code || "";
      if (code === "actions_forbidden" || code === "github_unconfigured") {
        state.pipeline.state = "error";
        state.pipeline.message = String(err.message || err);
        renderShell();
        return;
      }
      if (softFails >= 5) {
        state.pipeline.state = "error";
        state.pipeline.message = String(err.message || err);
        renderShell();
        return;
      }
    }

    await sleep(elapsed < 60_000 ? 2500 : 7000);
  }
}

function collectionAllowsCreate(col = state.collection) {
  if (!col || col.type !== "collection") return false;
  return col.operations?.create !== false;
}

function collectionAllowsDelete(col = state.collection) {
  if (!col) return false;
  return col.operations?.delete === true;
}

function sanitizeEntryKey(raw) {
  return String(raw || "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

function expandFilenamePattern(pattern, key) {
  const now = new Date();
  const y = String(now.getFullYear());
  const m = String(now.getMonth() + 1).padStart(2, "0");
  const d = String(now.getDate()).padStart(2, "0");
  return String(pattern || "{key}.md")
    .replaceAll("{year}", y)
    .replaceAll("{month}", m)
    .replaceAll("{day}", d)
    .replaceAll("{key}", key);
}

function todayIsoDate() {
  const now = new Date();
  return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
}

function toolbarActionButton({
  className,
  title,
  ariaLabel,
  action = null,
  disabled = false,
  onClick,
  icon,
  label = null,
  spinning = false,
}) {
  const kids = [
    el("span", {
      className:
        "material-symbols-outlined" + (spinning ? " studio-icon-spin" : ""),
      text: icon,
      "aria-hidden": "true",
    }),
  ];
  if (label) {
    kids.push(el("span", { className: "btn-label", text: label }));
  }
  return el(
    "button",
    {
      className,
      type: "button",
      title,
      "aria-label": ariaLabel,
      "data-studio-action": action,
      disabled,
      onClick,
    },
    kids
  );
}

function renderStudioToolbar({ brand = null, menuToggle = null } = {}) {
  const saveLabel = state.saving ? "Saving…" : state.dirty ? "Save" : "Saved";
  const saveIcon = state.saving ? "progress_activity" : state.dirty ? "save" : "check";
  const statusText = state.error ? "Error" : state.status || "";

  const brandCluster = el("div", { className: "studio-toolbar-brand" }, [
    brand,
    statusText
      ? el("span", {
          className: "status-pill studio-toolbar-status" + (state.error ? " error" : ""),
          text: statusText,
          title: state.error || state.errorDetail || state.status || "",
        })
      : null,
  ]);

  const actions = [renderThemeMenu()];

  // Theme → pipeline/Export → Revert → Save. Pipeline chip is always present.
  if (isLocalDevHost()) {
    const exportBusy = state.reexporting || state.pipeline.state === "syncing";
    actions.push(
      toolbarActionButton({
        className:
          "btn btn-tool btn-reexport" +
          (exportBusy ? " pipeline-running" : "") +
          (state.pipeline.state === "ok" && !exportBusy ? " pipeline-ok" : "") +
          (state.pipeline.state === "error" && !exportBusy ? " pipeline-error" : ""),
        title: exportBusy
          ? "Exporting content JSON locally"
          : "Export content JSON locally and reload",
        ariaLabel: exportBusy ? "Exporting locally" : "Export locally",
        action: "reexport",
        disabled: exportBusy,
        onClick: () => reexportLocalContent(),
        icon: exportBusy ? "progress_activity" : "sync",
        label: exportBusy ? "Exporting…" : "Export",
        spinning: exportBusy,
      })
    );
  } else {
    actions.push(renderPipelineChip());
  }

  actions.push(
    toolbarActionButton({
      className: "btn btn-tool",
      title: "Revert all edits to the last loaded or saved version",
      ariaLabel: "Discard edits",
      action: "discard",
      disabled: !state.file || !state.dirty || !state.baseline,
      onClick: () => discardChanges(),
      icon: "undo",
      label: "Revert",
    }),
    toolbarActionButton({
      className: "btn btn-tool btn-primary",
      title: state.saving
        ? "Saving this draft"
        : state.dirty
          ? "Commit this draft"
          : "No edits to commit yet",
      ariaLabel: saveLabel,
      action: "save",
      disabled: state.saving || !state.file || !state.dirty,
      onClick: () => saveCurrent(),
      icon: saveIcon,
      label: saveLabel,
      spinning: state.saving,
    })
  );

  const kids = [
    brandCluster,
    el("span", { className: "spacer", "aria-hidden": "true" }),
    ...actions,
  ];
  if (menuToggle) kids.push(menuToggle);
  return el("header", { className: "studio-toolbar studio-icon-bar" }, kids);
}

function clerkUserEmail(clerk) {
  if (!clerk || clerk.dev || !clerk.user) return "";
  const primary = clerk.user.primaryEmailAddress?.emailAddress;
  if (primary) return primary;
  const list = clerk.user.emailAddresses || [];
  return list[0]?.emailAddress || "";
}

function renderAuthGate(clerk) {
  // Clerk refuses to show SignIn for an existing session and redirects to its
  // fallback (default `/` = site home). Never remount SignIn while signed in.
  if (clerk && !clerk.dev && clerk.user) {
    renderSignedInApiErrorGate(
      clerk,
      state.error || "Studio API session failed while you are signed in."
    );
    return;
  }

  app.innerHTML = "";
  const box = el("div", { className: "auth-gate" }, [
    el("div", { className: "studio-brand" }, [
      studioMark({ size: 32, label: "Studio" }),
      el("strong", { text: "Studio" }),
    ]),
    el("h1", { text: "Sign in to edit" }),
    el("p", {
      text: "Studio is for site admins only. Anyone may register; access is granted after review.",
    }),
    el("div", { id: "clerk-sign-in" }),
  ]);
  app.append(box);
  if (clerk && !clerk.dev) {
    clerk.mountSignIn($("#clerk-sign-in"), { ...CLERK_REDIRECTS });
  } else {
    $("#clerk-sign-in").append(
      el("p", {
        className: "status-pill",
        text: "No VITE_CLERK_PUBLISHABLE_KEY — using API bypass if enabled.",
      }),
      el("button", {
        className: "btn btn-primary",
        text: "Continue",
        onClick: () => bootApp(clerk),
      })
    );
  }
}

/** Signed in with Clerk, but /api/studio/session failed (local Jekyll, misconfig, …). */
function renderSignedInApiErrorGate(clerk, message) {
  app.innerHTML = "";
  const box = el("div", { className: "auth-gate" }, [
    el("div", { className: "studio-brand" }, [
      studioMark({ size: 32, label: "Studio" }),
      el("strong", { text: "Studio" }),
    ]),
    el("h1", { text: "Studio API unavailable" }),
    el("p", {
      className: "status-pill error",
      text: message || "Session request failed.",
    }),
    el("p", {
      text: "You are signed in with Clerk, but /api/studio/session did not succeed. Local jekyll serve has no Pages Functions — use a Pages preview, wrangler pages dev, or STUDIO_DEV_BYPASS against a running Function.",
    }),
    el("button", {
      className: "btn",
      type: "button",
      text: "Sign out",
      onClick: async () => {
        if (clerk && !clerk.dev && clerk.signOut) {
          await clerk.signOut({ redirectUrl: STUDIO_PATH });
          return;
        }
        renderAuthGate(clerk);
      },
    }),
  ]);
  app.append(box);
}

/** Signed-in but not on STUDIO_ALLOWLIST — polite brick wall. */
function renderPendingReviewGate(clerk, emailHint) {
  const email = emailHint || clerkUserEmail(clerk) || "the address you used to register";
  app.innerHTML = "";
  const p1 = el("p", { className: "pending-copy" });
  p1.append(
    document.createTextNode(
      "Thank you for your registration. Your profile is being transferred to the site administration to be reviewed as a potential contributor. You will be contacted via "
    )
  );
  const bold = document.createElement("strong");
  bold.textContent = email;
  p1.append(bold);
  p1.append(document.createTextNode("."));

  const box = el("div", { className: "auth-gate auth-gate--pending" }, [
    el("div", { className: "studio-brand" }, [
      studioMark({ size: 32, label: "Studio" }),
      el("strong", { text: "Studio" }),
    ]),
    el("h1", { text: "Registration received" }),
    p1,
    el("p", {
      className: "pending-signoff",
      text: "Have a nice one! ✍️",
    }),
    el("button", {
      className: "btn",
      type: "button",
      text: "Sign out",
      onClick: async () => {
        if (clerk && !clerk.dev && clerk.signOut) {
          await clerk.signOut({ redirectUrl: STUDIO_PATH });
          return;
        }
        renderAuthGate(clerk);
      },
    }),
  ]);
  app.append(box);
}

/** Left-nav / map section order. */
const NAV_GROUP_ORDER = [
  "Writing",
  "Portfolio",
  "References",
  "Pages",
  "CV Summary",
  "Presentation",
  "Profile",
];

function collectionGroups(schema) {
  const map = new Map();
  for (const c of schema.collections) {
    if (!map.has(c.group)) map.set(c.group, []);
    map.get(c.group).push(c);
  }
  const ordered = new Map();
  for (const group of NAV_GROUP_ORDER) {
    if (map.has(group)) ordered.set(group, map.get(group));
  }
  for (const [group, cols] of map) {
    if (!ordered.has(group)) ordered.set(group, cols);
  }
  return ordered;
}

/** Left-nav Media section (Library → content/media browser). */
function renderMediaNavGroup() {
  const group = "Media";
  const open = state.navOpenGroups.has(group);
  const items = el("div", {
    className: "studio-nav-group-items",
    id: navGroupDomId(group),
    role: "region",
    "aria-label": group,
  });
  if (!open) items.hidden = true;
  items.append(
    el("button", {
      className: "nav-item",
      type: "button",
      text: "Library",
      title: "Browse and upload under content/media",
      "aria-current": state.mediaOpen ? "page" : null,
      onClick: () => openMediaLibrary(),
    })
  );
  const toggle = el("button", {
    className: "studio-nav-group-toggle",
    type: "button",
    title: groupHint(group),
    "aria-expanded": open ? "true" : "false",
    "aria-controls": items.id,
    onClick: () => {
      toggleNavGroup(group);
    },
  }, [
    el("span", {
      className: "material-symbols-outlined",
      text: open ? "expand_more" : "chevron_right",
      "aria-hidden": "true",
    }),
    el("span", {
      className: "nav-group-label",
      text: group,
    }),
  ]);
  return el("div", { className: "studio-nav-group" }, [toggle, items]);
}

/**
 * Full failure sentence under the toolbar. The status pill is one line beside
 * Dark / Discard / Save, so on a phone it ellipsizes to the error code.
 */
function renderErrorBanner() {
  if (!state.error) return null;
  // The collection list already paints .list-error with the same sentence.
  if (!state.file && !state.mediaOpen) return null;
  const actions = [];
  if (state.errorCode === "conflict" && state.file) {
    const path = state.file;
    actions.push(
      el("button", {
        className: "btn",
        type: "button",
        text: "Reload from GitHub",
        title: "Replace this screen with the file currently on GitHub",
        onClick: () => openFile(path),
      })
    );
  }
  actions.push(
    el("button", {
      className: "btn",
      type: "button",
      text: "Dismiss",
      onClick: () => {
        clearError();
        renderShell();
      },
    })
  );
  return el("div", { className: "studio-error-banner", role: "alert" }, [
    el("p", { className: "studio-error-message", text: state.error }),
    el("div", { className: "studio-error-actions" }, actions),
  ]);
}

function renderShell() {
  app.innerHTML = "";
  const groups = collectionGroups(state.schema);
  const menuOpen = !!state.navMenuOpen;

  const brand = el("button", {
    className: "studio-brand studio-brand-home studio-brand-toolbar",
    type: "button",
    title: "Studio home",
    "aria-current": !state.collection && !state.mediaOpen ? "page" : null,
    onClick: () => goHome(),
  }, [
    studioMark({ size: 22 }),
    el("span", { className: "studio-brand-copy" }, [
      el("span", { className: "studio-brand-name", text: "Studio" }),
    ]),
  ]);

  const menuToggle = el("button", {
    className: "studio-nav-menu-toggle",
    type: "button",
    title: menuOpen ? "Close collections menu" : "Open collections menu",
    "aria-label": menuOpen
      ? `Close menu (${currentNavLabel()})`
      : `Open menu (${currentNavLabel()})`,
    "aria-expanded": menuOpen ? "true" : "false",
    "aria-controls": "studio-nav-panel",
    onClick: () => {
      state.navMenuOpen = !state.navMenuOpen;
      renderShell();
    },
  }, [
    el("span", {
      className: "studio-nav-menu-label sr-only",
      text: currentNavLabel(),
    }),
    el("span", {
      className: "material-symbols-outlined",
      text: menuOpen ? "close" : "menu",
      "aria-hidden": "true",
    }),
  ]);

  const panel = el("div", {
    className: "studio-nav-panel",
    id: "studio-nav-panel",
  });

  panel.append(renderMediaNavGroup());

  for (const [group, cols] of groups) {
    const open = state.navOpenGroups.has(group);
    const items = el("div", {
      className: "studio-nav-group-items",
      id: navGroupDomId(group),
      role: "region",
      "aria-label": group,
    });
    if (!open) items.hidden = true;

    for (const col of cols) {
      const count = state.navCountByCollection[col.name];
      const labelKids = [
        el("span", { className: "nav-item-label", text: col.label }),
      ];
      if (count != null) {
        labelKids.push(
          el("span", {
            className: "nav-item-count",
            text: String(count),
          })
        );
      }
      items.append(
        el("button", {
          className: "nav-item",
          type: "button",
          title: collectionHint(col),
          "aria-current":
            state.collection?.name === col.name ? "page" : null,
          onClick: () => selectCollection(col),
        }, labelKids)
      );
    }

    const toggle = el("button", {
      className: "studio-nav-group-toggle",
      type: "button",
      title: groupHint(group),
      "aria-expanded": open ? "true" : "false",
      "aria-controls": items.id,
      onClick: () => {
        toggleNavGroup(group);
      },
    }, [
      el("span", {
        className: "material-symbols-outlined",
        text: open ? "expand_more" : "chevron_right",
        "aria-hidden": "true",
      }),
      el("span", {
        className: "nav-group-label",
        text: group,
      }),
    ]);

    panel.append(el("div", { className: "studio-nav-group" }, [toggle, items]));
  }

  const nav = el(
    "nav",
    {
      className: "studio-nav" + (menuOpen ? " is-open" : ""),
      "aria-label": "Collections",
    },
    [panel]
  );

  const toolbar = renderStudioToolbar({ brand, menuToggle });

  const main = el("div", { className: "studio-main" }, [
    renderErrorBanner(),
    renderStudioBreadcrumb(),
    el("div", {
      className: "studio-body" + (state.file ? "" : " list-only"),
      id: "studio-body",
    }),
  ]);

  app.append(el("div", { className: "studio-shell" }, [toolbar, nav, main]));
  renderMain();
  syncThemeMenuUi();
  if (!window.__studioMenuDismissBound) {
    window.__studioMenuDismissBound = true;
    document.addEventListener("click", () => {
      if (state.themeMenuOpen) {
        state.themeMenuOpen = false;
        syncThemeMenuUi();
      }
    });
  }
}

function renderStudioBreadcrumb() {
  const parts = [el("span", { className: "studio-crumb", text: "Studio" })];
  if (state.mediaOpen && !state.collection) {
    parts.push(
      el("span", { className: "studio-crumb-sep", "aria-hidden": "true", text: "/" }),
      el("span", { className: "studio-crumb is-current", text: "Media" })
    );
  } else if (state.collection) {
    const group = state.collection.group || "Content";
    const label = state.collection.label || state.collection.name;
    parts.push(
      el("span", { className: "studio-crumb-sep", "aria-hidden": "true", text: "/" }),
      el("span", { className: "studio-crumb", text: group }),
      el("span", { className: "studio-crumb-sep", "aria-hidden": "true", text: "/" }),
      el("span", {
        className: "studio-crumb" + (state.file ? "" : " is-current"),
        text: label,
      })
    );
    if (state.file) {
      const leaf =
        state.fields?.title ||
        state.fields?.key ||
        String(state.file).split("/").pop() ||
        "Entry";
      parts.push(
        el("span", { className: "studio-crumb-sep", "aria-hidden": "true", text: "/" }),
        el("span", { className: "studio-crumb is-current", text: leaf })
      );
    }
  } else {
    parts.push(
      el("span", { className: "studio-crumb-sep", "aria-hidden": "true", text: "/" }),
      el("span", { className: "studio-crumb is-current", text: "Map" })
    );
  }
  return el("nav", {
    className: "studio-breadcrumb",
    "aria-label": "Location",
  }, parts);
}

/** Flip Save / Discard as soon as an edit lands, without rebuilding the form. */
function markDirty() {
  state.dirty = true;
  syncCommitButtons();
  refreshBodyStats();
}

function canAiProof() {
  if (!state.file || isYamlCollection()) return false;
  if (state.aiProofBusy) return false;
  return Boolean(String(state.fields?.language || "").trim());
}

function syncAiProofControls() {
  const busy = state.aiProofBusy;
  const enabled = canAiProof() && !busy;
  for (const action of ["correct", "refine"]) {
    const item = document.querySelector(`[data-studio-action='${action}']`);
    if (!item) continue;
    item.disabled = !enabled;
    const label = item.querySelector(".editor-ai-proof-label");
    if (!label) continue;
    if (busy) label.textContent = "Working…";
    else label.textContent = action === "refine" ? "Refine" : "Correct";
  }
}

function closeEditorMenus() {
  state.insertMenuOpen = false;
  const insert = $("#insert-menu");
  if (insert) insert.hidden = true;
  for (const btn of document.querySelectorAll(
    ".editor-insert-btn[aria-haspopup='menu']"
  )) {
    btn.setAttribute("aria-expanded", "false");
  }
}

function flashAiProofHint(message) {
  state.aiProofHint = message;
  const host = $("#ai-proof-hint");
  if (host) {
    host.textContent = message;
    host.hidden = !message;
  }
  clearTimeout(state._aiProofHintTimer);
  if (!message) return;
  state._aiProofHintTimer = setTimeout(() => {
    state.aiProofHint = "";
    const elHint = $("#ai-proof-hint");
    if (elHint) {
      elHint.textContent = "";
      elHint.hidden = true;
    }
  }, 3200);
}

/**
 * Body selection for AI Proof. Source uses markdown offsets; Visual uses TipTap positions.
 * @returns {{ kind: "source"|"visual", text: string, start?: number, end?: number, from?: number, to?: number } | null}
 */
function getBodySelection() {
  if (state.bodyMode === "source") {
    const source = $("#body-source");
    if (!source) return null;
    const start = source.selectionStart;
    const end = source.selectionEnd;
    if (!Number.isInteger(start) || !Number.isInteger(end) || start === end) {
      return null;
    }
    syncBodyFromEditor();
    const full = state.body || "";
    return { kind: "source", start, end, text: full.slice(start, end) };
  }
  if (state.bodyMode === "visual" && state.bodyEditor?.editor) {
    const ed = state.bodyEditor.editor;
    const { from, to, empty } = ed.state.selection;
    if (empty || from === to) return null;
    const text = ed.state.doc.textBetween(from, to, "\n\n");
    if (!String(text).trim()) return null;
    return { kind: "visual", from, to, text };
  }
  return null;
}

/** Apply patches from end → start so earlier offsets stay valid. */
function applyPatchesToText(text, patches) {
  const list = Array.isArray(patches) ? [...patches] : [];
  list.sort((a, b) => (b.start || 0) - (a.start || 0));
  let out = text;
  for (const p of list) {
    const start = Number(p.start);
    const end = Number(p.end);
    if (!Number.isInteger(start) || !Number.isInteger(end) || end < start) continue;
    const original = String(p.original ?? "");
    const replacement = String(p.replacement ?? "");
    if (out.slice(start, end) !== original) continue;
    out = out.slice(0, start) + replacement + out.slice(end);
  }
  return out;
}

function replaceBodySelection(sel, nextText) {
  if (sel.kind === "source") {
    const full = state.body || "";
    state.body = full.slice(0, sel.start) + nextText + full.slice(sel.end);
    const source = $("#body-source");
    if (source) {
      source.value = state.body;
      const caret = sel.start + nextText.length;
      source.focus();
      source.setSelectionRange(caret, caret);
    }
    markDirty();
    refreshPreview();
    return;
  }
  if (sel.kind === "visual" && state.bodyEditor?.editor) {
    state.bodyEditor.editor
      .chain()
      .focus()
      .insertContentAt({ from: sel.from, to: sel.to }, nextText)
      .run();
    syncBodyFromEditor();
    markDirty();
    refreshPreview();
  }
}

/**
 * Resolve the body range for Correct / Refine.
 * Spec §9.1: current selection when non-empty; otherwise the full body.
 * @returns {{ kind: "source"|"visual", text: string, start?: number, end?: number, from?: number, to?: number, wholeBody?: boolean } | null}
 */
function resolveAiProofTarget() {
  // Prefer the selection captured on mousedown — clicking the toolbar
  // otherwise blurs the editor and clears the live range before onClick.
  const live = state.aiProofSelection || getBodySelection();
  state.aiProofSelection = null;
  if (live) return live;

  syncBodyFromEditor();
  const full = state.body || "";
  if (!String(full).trim()) return null;

  if (state.bodyMode === "source") {
    return {
      kind: "source",
      start: 0,
      end: full.length,
      text: full,
      wholeBody: true,
    };
  }
  if (state.bodyMode === "visual" && state.bodyEditor?.editor) {
    const ed = state.bodyEditor.editor;
    const from = 0;
    const to = ed.state.doc.content.size;
    return {
      kind: "visual",
      from,
      to,
      text: full,
      wholeBody: true,
    };
  }
  return null;
}

/**
 * AC-PRF-01 / AC-PRF-16 — Correct or Refine on selection, else full body.
 * @param {"correct"|"refine"} mode
 */
async function startRewrite(mode) {
  closeEditorMenus();
  flashAiProofHint("");
  if (!canAiProof()) {
    flashAiProofHint("Set language in front matter before AI Proof.");
    syncCommitButtons();
    return;
  }

  const sel = resolveAiProofTarget();
  if (!sel) {
    flashAiProofHint("Body is empty.");
    return;
  }

  syncBodyFromEditor();
  const language = String(state.fields.language || "").trim();
  const full = state.body || "";
  let context = null;
  if (mode === "refine" && sel.kind === "source" && !sel.wholeBody) {
    context = {
      before: full.slice(Math.max(0, sel.start - 2000), sel.start),
      after: full.slice(sel.end, Math.min(full.length, sel.end + 2000)),
    };
  }

  const apiSelection =
    sel.kind === "source"
      ? { start: sel.start, end: sel.end }
      : { start: 0, end: sel.text.length };

  const scope = sel.wholeBody ? "body" : "selection";
  state.aiProofBusy = true;
  state.status =
    mode === "refine" ? `Refining ${scope}…` : `Correcting ${scope}…`;
  syncAiProofControls();

  try {
    const result = await studioApi.rewrite({
      mode,
      path: state.file,
      language,
      text: sel.text,
      selection: apiSelection,
      context,
    });
    const patches = Array.isArray(result.patches) ? result.patches : [];
    const stats = result.stats || {};
    if (!patches.length) {
      if (Number(stats.proposed) > 0) {
        state.status = `No safe changes to apply (${stats.proposed} proposed, all dropped).`;
      } else {
        state.status = `No changes proposed for the ${scope}.`;
      }
      return;
    }

    let nextText;
    if (sel.kind === "visual" && sel.wholeBody) {
      // Spec §16.1: apply on markdown body, then re-hydrate TipTap.
      nextText = applyPatchesToText(full, patches);
      if (nextText === full) {
        state.status = `No changes proposed for the ${scope}.`;
        return;
      }
      state.body = nextText;
      state.bodyEditor?.setMarkdown?.(nextText);
      markDirty();
      refreshPreview();
    } else {
      nextText = applyPatchesToText(sel.text, patches);
      if (nextText === sel.text) {
        state.status = `No changes proposed for the ${scope}.`;
        return;
      }
      replaceBodySelection(sel, nextText);
    }

    const dropped =
      Number(stats.dropped) > 0 ? `, ${stats.dropped} dropped` : "";
    state.status =
      mode === "refine"
        ? `Refined ${scope} (${patches.length}${dropped}).`
        : `Corrected ${scope} (${patches.length}${dropped}).`;
  } catch (err) {
    captureError(err);
    const detail = state.error;
    state.error = detail ? `AI Proof failed. ${detail}` : "AI Proof failed.";
  } finally {
    state.aiProofBusy = false;
    syncAiProofControls();
    syncCommitButtons();
  }
}

function syncCommitButtons() {
  const save = document.querySelector("[data-studio-action='save']");
  const discard = document.querySelector("[data-studio-action='discard']");
  if (save) {
    const saveLabel = state.saving ? "Saving…" : state.dirty ? "Save" : "Saved";
    save.disabled = state.saving || !state.file || !state.dirty;
    save.title = state.saving
      ? "Saving this draft"
      : state.dirty
        ? "Commit this draft"
        : "No edits to commit yet";
    save.setAttribute("aria-label", saveLabel);
    const icon = save.querySelector(".material-symbols-outlined");
    if (icon) {
      icon.textContent = state.saving
        ? "progress_activity"
        : state.dirty
          ? "save"
          : "check";
      icon.classList.toggle("studio-icon-spin", state.saving);
    }
    const label = save.querySelector(".btn-label");
    if (label) label.textContent = saveLabel;
  }
  if (discard) {
    discard.disabled = !state.file || !state.dirty || !state.baseline;
  }
  syncAiProofControls();
}

function renderMain() {
  const body = $("#studio-body");
  if (!body) return;
  body.innerHTML = "";
  const modeClass =
    state.file && !isYamlCollection() ? ` view-${state.bodyMode}` : "";
  body.className =
    "studio-body" + (state.file ? "" : " list-only") + modeClass;

  if (state.fileLoading) {
    body.append(
      el("div", { className: "pane" }, [
        el("p", { className: "loading-msg", text: "Loading content…" }),
      ])
    );
    return;
  }

  if (!state.collection) {
    if (state.mediaOpen) {
      body.append(renderMediaPane(mediaOpts()));
      return;
    }
    body.append(renderStudioMap());
    return;
  }

  if (!state.file) {
    body.append(renderListPane());
    return;
  }

  if (isYamlCollection()) {
    body.append(renderYamlEditorPane(), renderPreviewPane());
    refreshPreview();
    return;
  }

  body.append(renderEditorPane(), renderPreviewPane());
  mountBodyEditor();
  refreshPreview();
}

function isYamlCollection(col = state.collection) {
  return col?.format === "yaml";
}

function syncYamlSourceFromStructured() {
  const col = state.collection;
  const kind = yamlEditKind(col);
  try {
    if (kind === "list") {
      state.body = dumpYaml(state.yamlList || []);
    } else if (kind === "map") {
      if (col.root_key) {
        const doc =
          state.yamlDoc && typeof state.yamlDoc === "object"
            ? { ...state.yamlDoc }
            : {};
        doc[col.root_key] = pruneEmptyFields(
          { ...state.fields },
          col.fields
        );
        state.body = dumpYaml(doc);
      } else {
        state.body = dumpYaml(
          pruneEmptyFields({ ...state.fields }, col.fields)
        );
      }
    }
  } catch (err) {
    captureError(err);
  }
}

function applyYamlSourceToStructured() {
  const col = state.collection;
  const kind = yamlEditKind(col);
  clearError();
  try {
    const doc = loadYaml(state.body);
    if (kind === "list") {
      state.yamlList = asObjectList(doc);
      state.fields = {};
    } else if (kind === "map") {
      if (col.root_key) {
        const root = asObjectMap(doc);
        state.yamlDoc = root;
        state.fields = asObjectMap(root[col.root_key]);
      } else {
        state.yamlDoc = null;
        state.fields = asObjectMap(doc);
      }
      state.yamlList = null;
    }
    return true;
  } catch (err) {
    captureError(err);
    state.status = "Invalid YAML — fix source before switching";
    return false;
  }
}

function setYamlUiMode(mode) {
  if (mode === state.yamlUiMode) return;
  if (mode === "source") {
    syncYamlSourceFromStructured();
    state.yamlUiMode = "source";
    renderShell();
    return;
  }
  // structured
  const source = $("#yaml-source");
  if (source) state.body = source.value;
  if (!applyYamlSourceToStructured()) {
    renderShell();
    return;
  }
  state.yamlUiMode = "structured";
  renderShell();
}

function renderYamlEditorChrome(kind) {
  const structured = state.yamlUiMode === "structured" && kind !== "source";
  const canStructure = kind === "list" || kind === "map";
  if (!canStructure) {
    return el("div", { className: "editor-chrome yaml-chrome" }, [
      el("p", {
        className: "yaml-chrome-hint",
        text: "Free-form YAML — edit the source directly.",
      }),
    ]);
  }

  return el("div", { className: "editor-chrome yaml-chrome" }, [
    el("div", {
      className: "editor-mode-tabs",
      role: "tablist",
      "aria-label": "YAML editor mode",
    }, [
      el("button", {
        className: "editor-mode-tab",
        type: "button",
        role: "tab",
        text: "Fields",
        title: "Structured field editors",
        "aria-selected": structured ? "true" : "false",
        onClick: () => setYamlUiMode("structured"),
      }),
      el("button", {
        className: "editor-mode-tab",
        type: "button",
        role: "tab",
        text: "YAML",
        title: "Raw YAML source",
        "aria-selected": !structured ? "true" : "false",
        onClick: () => setYamlUiMode("source"),
      }),
    ]),
    el("p", {
      className: "yaml-chrome-hint",
      text:
        kind === "list"
          ? "List of entries in one YAML file. Reorder, add, or remove items."
          : "Structured YAML fields — not a Markdown article body.",
    }),
  ]);
}

function renderYamlListEditor() {
  const col = state.collection;
  const fields = nonBodyFields(col);
  const list = Array.isArray(state.yamlList) ? state.yamlList : [];
  const host = el("div", { className: "yaml-list", id: "yaml-list" });

  list.forEach((raw, index) => {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
      list[index] = {};
    }
    const item = list[index];
    const card = el("div", { className: "yaml-list-item" });
    const primaryField = fields[0];
    const primaryVal = primaryField
      ? item[primaryField.name] || `${col.label} ${index + 1}`
      : `${col.label} ${index + 1}`;
    card.append(
      el("div", { className: "yaml-list-item-head" }, [
        el("span", {
          className: "yaml-list-item-index",
          text: String(primaryVal),
        }),
        el("div", { className: "yaml-list-item-actions" }, [
          el("button", {
            className: "btn yaml-list-btn",
            type: "button",
            text: "↑",
            title: "Move up",
            disabled: index === 0,
            onClick: () => {
              if (index === 0) return;
              const next = [...list];
              [next[index - 1], next[index]] = [next[index], next[index - 1]];
              state.yamlList = next;
              markDirty();
              renderShell();
            },
          }),
          el("button", {
            className: "btn yaml-list-btn",
            type: "button",
            text: "↓",
            title: "Move down",
            disabled: index === list.length - 1,
            onClick: () => {
              if (index >= list.length - 1) return;
              const next = [...list];
              [next[index], next[index + 1]] = [next[index + 1], next[index]];
              state.yamlList = next;
              markDirty();
              renderShell();
            },
          }),
          el("button", {
            className: "btn yaml-list-btn",
            type: "button",
            text: "Remove",
            onClick: () => {
              state.yamlList = list.filter((_, i) => i !== index);
              markDirty();
              renderShell();
            },
          }),
        ]),
      ])
    );
    const form = el("div", { className: "form-grid yaml-list-item-fields" });
    for (const field of fields) {
      form.append(
        renderField(field, {
          target: item,
          idPrefix: `yml-${index}-`,
          onChange: () => {
            markDirty();
          },
        })
      );
    }
    card.append(form);
    host.append(card);
  });

  host.append(
    el("button", {
      className: "btn btn-primary",
      type: "button",
      text: "Add item",
      onClick: () => {
        state.yamlList = [
          ...(state.yamlList || []),
          emptyItemFromFields(fields),
        ];
        markDirty();
        renderShell();
      },
    })
  );

  if (!list.length) {
    host.prepend(
      el("p", {
        className: "yaml-empty",
        text: "No items yet. Add one to start this list.",
      })
    );
  }

  return host;
}

function renderYamlMapEditor() {
  const form = el("div", { className: "form-grid", id: "yaml-form" });
  for (const field of nonBodyFields(state.collection)) {
    form.append(renderField(field));
  }
  return form;
}

function renderYamlSourceEditor() {
  return el("div", { className: "field yaml-source-stack" }, [
    el("label", { className: "field-heading", text: "YAML source" }),
    el("textarea", {
      id: "yaml-source",
      className: "yaml-source editor-surface",
      text: state.body,
      "aria-label": "YAML source",
      spellcheck: "false",
      onInput: (e) => {
        state.body = e.target.value;
        markDirty();
        refreshPreview();
      },
    }),
  ]);
}

function renderYamlEditorPane() {
  const col = state.collection;
  const kind = yamlEditKind(col) || "source";
  const useStructured =
    state.yamlUiMode === "structured" && (kind === "list" || kind === "map");

  const backTarget = col.type === "file" ? "Map" : "List";
  const body = el("div", { className: "yaml-editor-body" });
  if (useStructured && kind === "list") {
    body.append(renderYamlListEditor());
  } else if (useStructured && kind === "map") {
    body.append(renderYamlMapEditor());
  } else {
    body.append(renderYamlSourceEditor());
  }

  return el("div", { className: "pane pane-editor pane-yaml" }, [
    el("button", {
      className: "btn btn-nav",
      type: "button",
      title: `Back to ${backTarget}`,
      onClick: () => {
        destroyBodyEditor();
        if (col.type === "file") {
          goHome();
          return;
        }
        state.file = null;
        state.baseline = null;
        state.dirty = false;
        state.insertMenuOpen = false;
        renderShell();
      },
    }, [
      materialIcon("chevron_left", "btn-nav-icon"),
      el("span", { text: backTarget }),
    ]),
    el("header", { className: "yaml-editor-header" }, [
      el("h1", {
        className: "yaml-editor-title",
        text: col.label,
      }),
      el("p", {
        className: "yaml-editor-path",
        text: formatPath(state.file || col.path),
      }),
    ]),
    renderYamlEditorChrome(kind),
    body,
  ]);
}

function renderStudioMap() {
  const groups = collectionGroups(state.schema);
  const sections = [renderMediaMapSection()];

  for (const [group, cols] of groups) {
    const cards = cols.map((col) =>
      el("button", {
        className: "studio-map-card",
        type: "button",
        title: collectionHint(col),
        onClick: () => {
          state.navOpenGroups.add(group);
          selectCollection(col);
        },
      }, [
        materialIcon(
          col.type === "file" ? "draft" : GROUP_ICONS[group] || "folder_open",
          "studio-map-card-icon"
        ),
        el("span", { className: "studio-map-card-body" }, [
          el("span", { className: "studio-map-card-title", text: col.label }),
          el("span", {
            className: "studio-map-card-meta",
            text: formatPath(col.path) || col.name,
          }),
        ]),
      ])
    );

    sections.push(
      el("section", { className: "studio-map-group" }, [
        el("div", { className: "studio-map-group-head" }, [
          materialIcon(GROUP_ICONS[group] || "folder", "studio-map-group-icon"),
          el("h2", { className: "studio-map-group-label", text: group }),
        ]),
        el("div", { className: "studio-map-grid" }, cards),
      ])
    );
  }

  return el("div", { className: "pane studio-map" }, [
    el("span", {
      className: "studio-shard studio-shard--lead",
      "aria-hidden": "true",
    }),
    el("span", {
      className: "studio-shard studio-shard--beta studio-shard--trail",
      "aria-hidden": "true",
    }),
    el(
      "div",
      {
        className: "studio-map-board",
        role: "navigation",
        "aria-label": "Collections map",
      },
      sections
    ),
  ]);
}

function renderMediaMapSection() {
  return el("section", { className: "studio-map-group" }, [
    el("div", { className: "studio-map-group-head" }, [
      materialIcon(GROUP_ICONS.Media || "photo_library", "studio-map-group-icon"),
      el("h2", { className: "studio-map-group-label", text: "Media" }),
    ]),
    el("div", { className: "studio-map-grid" }, [
      el("button", {
        className: "studio-map-card",
        type: "button",
        title: "Browse and upload under content/media",
        onClick: () => openMediaLibrary(),
      }, [
        materialIcon("photo_library", "studio-map-card-icon"),
        el("span", { className: "studio-map-card-body" }, [
          el("span", { className: "studio-map-card-title", text: "Library" }),
          el("span", {
            className: "studio-map-card-meta",
            text: formatPath("content/media"),
          }),
        ]),
      ]),
    ]),
  ]);
}

function renderListPane() {
  const query = currentListQuery();
  const sortId = currentListSortId();
  const pageSizeId = currentListPageSizeId();
  const writing = isWritingCollection();
  const filtered = applyListControls(state.items, {
    query,
    sortId,
  });
  const pageInfo = paginateItems(filtered, {
    pageSizeId,
    page: currentListPage(),
  });
  // Clamp stored page if filter/sort shrunk the result set.
  if (pageInfo.page !== currentListPage()) {
    setListPage(pageInfo.page);
  }
  const visible = pageInfo.items;

  const header = renderListHeader(state.collection, {
    entryCount: state.listLoading ? null : state.items.length,
  });

  if (state.listLoading) {
    return el("div", { className: "pane" }, [
      header,
      el("p", { className: "loading-msg", text: "Loading content…" }),
    ]);
  }

  if (state.error && !state.items.length) {
    return el("div", { className: "pane" }, [
      header,
      el("div", { className: "list-error" }, [
        el("p", {
          className: "list-error-title",
          text: "Could not load entries.",
        }),
        el("p", { className: "list-error-message", text: state.error }),
        state.errorDetail
          ? el("pre", {
              className: "list-error-detail",
              text: state.errorDetail,
            })
          : null,
      ]),
    ]);
  }

  const rows = visible.map((item) => renderLedgerRow(item, writing));

  const search = el("input", {
    className: "list-search-input",
    type: "search",
    value: query,
    placeholder: "Search title, key, path…",
    "aria-label": "Search entries",
    title: "Filter this list by title, key, filename, or path",
    onInput: (e) => {
      const name = state.collection?.name;
      if (!name) return;
      state.listQueryByCollection[name] = e.target.value;
      resetListPage();
      renderMain();
      const next = $("#list-search-input");
      if (next) {
        next.focus();
        const len = next.value.length;
        next.setSelectionRange(len, len);
      }
    },
  });
  search.id = "list-search-input";

  const sortSelect = el("select", {
    className: "list-sort-select",
    "aria-label": "Sort entries",
    title: "Sort entries in this collection",
    onChange: (e) => {
      setListSortId(e.target.value);
      renderMain();
    },
  });
  for (const opt of LIST_SORT_OPTIONS) {
    sortSelect.append(
      el("option", {
        value: opt.id,
        text: opt.label,
        selected: opt.id === sortId,
      })
    );
  }

  const pageSizeSelect = el("select", {
    className: "list-page-size-select",
    "aria-label": "Entries per page",
    title: "How many entries to show per page",
    onChange: (e) => {
      setListPageSizeId(e.target.value);
      renderMain();
    },
  });
  for (const opt of LIST_PAGE_SIZE_OPTIONS) {
    pageSizeSelect.append(
      el("option", {
        value: opt.id,
        text: opt.label,
        selected: opt.id === pageSizeId,
      })
    );
  }

  const controls = el("div", { className: "list-controls" }, [
    search,
    el("label", { className: "list-sort-label" }, [
      el("span", { className: "list-sort-caption", text: "Sort" }),
      sortSelect,
    ]),
    el("label", { className: "list-sort-label" }, [
      el("span", { className: "list-sort-caption", text: "Show" }),
      pageSizeSelect,
    ]),
  ]);

  let emptyNode = null;
  if (!filtered.length) {
    if (state.error) {
      emptyNode = el("div", { className: "list-error" }, [
        el("p", {
          className: "list-error-title",
          text: "Could not load entries.",
        }),
        el("p", { className: "list-error-message", text: state.error }),
        state.errorDetail
          ? el("pre", {
              className: "list-error-detail",
              text: state.errorDetail,
            })
          : null,
      ]);
    } else if (state.items.length === 0) {
      emptyNode = el("p", {
        className: "list-empty",
        text: "No entries in this collection.",
      });
    } else {
      emptyNode = el("p", {
        className: "list-empty",
        text: "No entries match this search.",
      });
    }
  }

  const showPager =
    pageInfo.pageSize != null && pageInfo.pageCount > 1 && filtered.length > 0;
  const pager = showPager
    ? el("div", { className: "list-pager", role: "navigation", "aria-label": "List pages" }, [
        el("button", {
          className: "btn list-pager-btn",
          type: "button",
          text: "Prev",
          title: "Previous page",
          disabled: pageInfo.page <= 1,
          onClick: () => {
            if (pageInfo.page <= 1) return;
            setListPage(pageInfo.page - 1);
            renderMain();
          },
        }),
        el("span", {
          className: "list-pager-status",
          text: `Page ${pageInfo.page} of ${pageInfo.pageCount}`,
        }),
        el("button", {
          className: "btn list-pager-btn",
          type: "button",
          text: "Next",
          title: "Next page",
          disabled: pageInfo.page >= pageInfo.pageCount,
          onClick: () => {
            if (pageInfo.page >= pageInfo.pageCount) return;
            setListPage(pageInfo.page + 1);
            renderMain();
          },
        }),
      ])
    : null;

  // Title already shows total entry count — list-count only when range/filter adds info.
  let countText = "";
  if (state.items.length > 0) {
    const filteredNote = query;
    if (!filtered.length) {
      countText = filteredNote ? `0 of ${state.items.length}` : "";
    } else if (pageInfo.pageSize == null) {
      countText = filteredNote
        ? `${filtered.length} of ${state.items.length}`
        : "";
    } else {
      const range = `${pageInfo.from}–${pageInfo.to} of ${filtered.length}`;
      countText = filteredNote
        ? `${range} (filtered from ${state.items.length})`
        : range;
    }
  }

  const columnHead = writing
    ? el("div", { className: "ledger-columns", "aria-hidden": "true" }, [
        el("span", { className: "ledger-col-thumb" }),
        el("span", { className: "ledger-col-manuscript", text: "Manuscript" }),
        el("span", { className: "ledger-col-ops", text: "Operations" }),
      ])
    : null;

  return el("div", { className: "pane" }, [
    header,
    controls,
    countText
      ? el("p", { className: "list-count", text: countText })
      : null,
    columnHead,
    el("div", { className: "ledger-list" }, rows.length ? rows : [emptyNode]),
    pager,
  ]);
}

function languageChip(itemOrFields) {
  const lang = String(itemOrFields?.language || "").trim();
  if (!lang) return null;
  return el("span", {
    className: "ledger-lang",
    text: lang.toUpperCase(),
    title: `Language: ${lang}`,
  });
}

function renderLedgerOps(item, { open }) {
  const canDelete = collectionAllowsDelete();
  const label = item.title || item.name || "entry";
  const editBtn = el(
    "button",
    {
      className: "btn btn-icon ledger-op-btn ledger-edit-btn",
      type: "button",
      title: `Edit ${label}`,
      "aria-label": `Edit ${label}`,
      onClick: (e) => {
        e.stopPropagation();
        open();
      },
    },
    [materialIcon("edit")]
  );
  const deleteBtn = canDelete
    ? el(
        "button",
        {
          className: "btn btn-icon ledger-op-btn ledger-delete-btn",
          type: "button",
          title: `Delete ${label}`,
          "aria-label": `Delete ${label}`,
          onClick: (e) => {
            e.stopPropagation();
            deleteEntry(item.path, item.sha);
          },
        },
        [materialIcon("delete")]
      )
    : null;
  return el("div", { className: "ledger-ops", role: "group", "aria-label": "Operations" }, [
    editBtn,
    deleteBtn,
  ]);
}

function renderLedgerRow(item, writing) {
  const metaText = formatEntryListMeta(item, state.collection);
  const open = () => openFile(item.path);
  const ops = renderLedgerOps(item, { open });

  if (!writing) {
    const titleBlock = el("div", { className: "ledger-copy" }, [
      el("div", {
        className: "ledger-title",
        text: item.title || item.name,
      }),
      metaText
        ? el("div", { className: "ledger-meta", text: metaText })
        : null,
    ]);
    return el(
      "div",
      {
        className: "ledger-row ledger-row--plain",
        role: "button",
        tabindex: "0",
        title: entryHint(item),
        onClick: open,
        onKeydown: (e) => {
          if (e.key === "Enter" || e.key === " ") {
            e.preventDefault();
            open();
          }
        },
      },
      [thumbnailNode(item), titleBlock, ops]
    );
  }

  const titleRow = el("div", { className: "ledger-title-row" }, [
    publishStatusPill(item),
    el("div", {
      className: "ledger-title",
      text: item.title || item.name,
    }),
  ]);

  const manuscript = el("div", { className: "ledger-copy" }, [
    titleRow,
    metaText
      ? el("div", { className: "ledger-meta", text: metaText })
      : null,
  ]);

  return el(
    "div",
    {
      className: "ledger-row ledger-row--writing",
      role: "button",
      tabindex: "0",
      title: entryHint(item),
      onClick: open,
      onKeydown: (e) => {
        if (e.key === "Enter" || e.key === " ") {
          e.preventDefault();
          open();
        }
      },
    },
    [thumbnailNode(item), manuscript, ops]
  );
}

function nonBodyFields(collection) {
  return (collection.fields || []).filter(
    (f) => !f.hidden && !fieldIsBody(f) && f.name !== "layout"
  );
}

function bodyFields(collection) {
  const bodies = (collection.fields || []).filter((f) => fieldIsBody(f));
  if (bodies.length) return bodies;
  // Raw markdown files without a body field: single source textarea (not TipTap chrome).
  if (collection.format === "raw" && !collection.root_key) {
    return [{ name: "body", label: "Content", component: "markdown_body" }];
  }
  // YAML never borrows the markdown body editor — see renderYamlEditorPane.
  return [];
}

function collectionHasField(col, name) {
  return (col?.fields || []).some((field) => field.name === name);
}

function fieldValuePresent(value) {
  if (value == null) return false;
  if (Array.isArray(value)) return value.length > 0;
  if (typeof value === "boolean") return true;
  return String(value).trim() !== "";
}

/** Open front-matter when dirty or a required meta field is empty. */
function shouldFrontMatterOpen() {
  if (state.frontMatterOpen != null) return !!state.frontMatterOpen;
  if (state.dirty) return true;
  for (const field of nonBodyFields(state.collection)) {
    if (!field.required) continue;
    if (!fieldValuePresent(state.fields?.[field.name])) return true;
  }
  return false;
}

function renderListHeader(collection, { entryCount = null } = {}) {
  const group = collection?.group || "Content";
  const label = collection?.label || collection?.name || "Index";
  const titleRow = [
    el("h1", { className: "list-pane-title", text: label }),
  ];
  if (entryCount != null && entryCount >= 0) {
    titleRow.push(
      el("span", {
        className: "list-pane-count",
        text:
          entryCount === 1 ? "1 entry" : `${entryCount} entries`,
      })
    );
  }
  if (collectionAllowsCreate(collection)) {
    titleRow.push(
      el(
        "button",
        {
          className: "btn btn-tool btn-primary list-new-btn",
          type: "button",
          title: `Add a new ${label} entry`,
          "aria-label": `New ${label} entry`,
          onClick: () => createNewEntry(),
        },
        [materialIcon("add"), el("span", { className: "btn-label", text: "New" })]
      )
    );
  }
  return el("header", { className: "list-register" }, [
    el("p", { className: "list-register-kicker" }, [
      el("span", { className: "list-register-mark", "aria-hidden": "true" }),
      el("span", { text: `Register // ${group}` }),
      el("span", { className: "list-register-sep", "aria-hidden": "true", text: "/" }),
      el("span", { text: `${label} index` }),
    ]),
    el("div", { className: "list-register-title-row" }, titleRow),
  ]);
}

function renderEditorPane() {
  const fields = nonBodyFields(state.collection);
  const bodies = bodyFields(state.collection);

  const form = el("div", { className: "form-grid", id: "meta-form" });

  for (const field of fields) {
    form.append(renderField(field));
  }

  const fmOpen = shouldFrontMatterOpen();
  const frontMatter =
    fields.length > 0
      ? el(
          "details",
          {
            className: "front-matter",
            open: fmOpen,
            onToggle: (e) => {
              state.frontMatterOpen = !!e.target.open;
            },
          },
          [
            el("summary", { className: "front-matter-summary" }, [
              el("span", {
                className: "front-matter-summary-label",
                text: "Front-matter",
              }),
              el("span", {
                className: "front-matter-summary-hint",
                text: fmOpen ? "Collapse" : "Expand",
              }),
            ]),
            form,
          ]
        )
      : null;

  const bodyWrap = el("div", { className: "field body-editor-stack", id: "body-wrap" });
  if (bodies.length) {
    const primary = bodies[0];
    const mode = state.bodyMode;
    const visual = mode === "visual";
    // On wide screens Preview is a side panel; keep a Visual surface mounted under Preview.
    const showVisualSurface = visual || mode === "preview";
    const showSourceSurface = mode === "source";

    const tiptapHost = el("div", {
      id: "tiptap-host",
      className: "tiptap editor-surface",
    });
    if (!showVisualSurface) tiptapHost.hidden = true;

    const source = el("textarea", {
      id: "body-source",
      className: "body-source editor-surface",
      text: state.body,
      "aria-label": "Markdown source",
      onInput: (e) => {
        state.body = e.target.value;
        markDirty();
        refreshPreview();
      },
    });
    if (!showSourceSurface) source.hidden = true;

    bodyWrap.append(
      el("label", { text: primary.label || "Body" }),
      renderEditorChrome(mode),
      el("div", { className: "editor-pane-fill" }, [tiptapHost, source])
    );
    if (bodies.length > 1) {
      for (const extra of bodies.slice(1)) {
        bodyWrap.append(
          el("label", {
            text: extra.label || extra.name,
            style: "margin-top:1rem",
          }),
          el("textarea", {
            "data-extra-body": extra.name,
            text: state.fields[extra.name] || "",
            onInput: (e) => {
              state.fields[extra.name] = e.target.value;
              markDirty();
            },
          })
        );
      }
    }
  }

  const bodyStats =
    bodies.length > 0
      ? renderBodyStats(state.body)
      : null;

  const mastPills = [];
  if (collectionHasField(state.collection, "published")) {
    mastPills.push(publishStatusPill(state.fields));
  }
  // Language field on the form is SOT — skip mast chip when that field exists.
  if (!collectionHasField(state.collection, "language")) {
    const lang = languageChip(state.fields);
    if (lang) mastPills.push(lang);
  }

  return el("div", { className: "pane pane-editor" }, [
    el("div", { className: "editor-mast" }, [
      el("div", { className: "editor-mast-lead" }, [
        el("button", {
          className: "btn btn-back",
          type: "button",
          title: "Back to collection list",
          "aria-label": "Back to collection list",
          onClick: () => {
            destroyBodyEditor();
            state.file = null;
            state.baseline = null;
            state.dirty = false;
            state.insertMenuOpen = false;
            state.frontMatterOpen = null;
            renderShell();
          },
        }, [materialIcon("chevron_left", "btn-nav-icon")]),
        mastPills.length
          ? el("div", { className: "editor-mast-pills" }, mastPills)
          : null,
      ]),
    ]),
    frontMatter,
    bodyWrap,
    bodyStats,
  ]);
}

function bodyTextStats(raw) {
  const text = String(raw || "");
  const chars = text.length;
  const trimmed = text.trim();
  const words = trimmed ? trimmed.split(/\s+/).filter(Boolean).length : 0;
  const paras = trimmed
    ? trimmed.split(/\n\s*\n/).filter((p) => p.trim()).length
    : 0;
  return { chars, words, paras };
}

function renderBodyStats(raw) {
  const { chars, words, paras } = bodyTextStats(raw);
  return el("div", { className: "editor-body-stats", id: "editor-body-stats" }, [
    el("span", { text: `Chars: ${chars}` }),
    el("span", { className: "editor-body-stats-sep", "aria-hidden": "true", text: "·" }),
    el("span", { text: `Words: ${words}` }),
    el("span", { className: "editor-body-stats-sep", "aria-hidden": "true", text: "·" }),
    el("span", { text: `Paras: ${paras}` }),
  ]);
}

function refreshBodyStats() {
  const host = $("#editor-body-stats");
  if (!host) return;
  const { chars, words, paras } = bodyTextStats(state.body);
  host.replaceChildren(
    el("span", { text: `Chars: ${chars}` }),
    el("span", { className: "editor-body-stats-sep", "aria-hidden": "true", text: "·" }),
    el("span", { text: `Words: ${words}` }),
    el("span", { className: "editor-body-stats-sep", "aria-hidden": "true", text: "·" }),
    el("span", { text: `Paras: ${paras}` })
  );
}

function renderEditorChrome(mode) {
  const visual = mode === "visual";
  const source = mode === "source";
  const preview = mode === "preview";

  const modeTabs = el("div", {
    className: "editor-mode-tabs",
    role: "tablist",
    "aria-label": "Editor mode",
  }, [
    el("button", {
      className: "editor-mode-tab",
      type: "button",
      role: "tab",
      text: "Visual",
      title: "Rich text with Liquid blocks",
      "aria-selected": visual ? "true" : "false",
      onClick: () => {
        if (visual) return;
        syncBodyFromEditor();
        state.bodyMode = "visual";
        state.lastEditorMode = "visual";
        closeEditorMenus();
        renderShell();
      },
    }),
    el("button", {
      className: "editor-mode-tab",
      type: "button",
      role: "tab",
      text: "Source",
      title: "Edit raw Markdown source",
      "aria-selected": source ? "true" : "false",
      onClick: () => {
        if (source) return;
        syncBodyFromEditor();
        state.bodyMode = "source";
        state.lastEditorMode = "source";
        closeEditorMenus();
        renderShell();
      },
    }),
    el("button", {
      className: "editor-mode-tab editor-mode-tab--preview",
      type: "button",
      role: "tab",
      text: "Preview",
      title: "Rendered side preview (small screens)",
      "aria-selected": preview ? "true" : "false",
      onClick: () => {
        if (preview) return;
        syncBodyFromEditor();
        if (state.bodyMode === "visual" || state.bodyMode === "source") {
          state.lastEditorMode = state.bodyMode;
        }
        state.bodyMode = "preview";
        closeEditorMenus();
        renderShell();
      },
    }),
  ]);

  const chromeRow = el("div", { className: "editor-chrome-row" }, [
    modeTabs,
    el("div", { className: "editor-chrome-actions" }, [
      visual || source ? renderAiProofControl() : null,
      visual ? renderInsertControl() : null,
    ]),
  ]);

  return el("div", { className: "editor-chrome" }, [
    chromeRow,
    el("p", {
      id: "ai-proof-hint",
      className: "ai-proof-hint",
      text: state.aiProofHint || "",
      hidden: !state.aiProofHint,
      "aria-live": "polite",
    }),
    visual ? renderFormatToolbar() : null,
  ]);
}

function promptIncludeAttrs(def) {
  const attrs = {};
  if (def.name === "figure") {
    attrs.src = prompt("Image URL (HTTPS or /media/…)") || "";
    attrs.caption = prompt("Caption") || "";
  } else if (def.name === "youtube") {
    attrs.id = prompt("YouTube id") || "";
  } else if (def.name === "xcite" || def.name === "cite") {
    attrs.key = prompt("Key") || "";
  } else {
    for (const f of def.fields) {
      const v = prompt(f);
      if (v) attrs[f] = v;
    }
  }
  return attrs;
}

function renderInsertControl() {
  const menu = el("div", {
    className: "editor-insert-menu",
    id: "insert-menu",
    role: "menu",
  });
  if (!state.insertMenuOpen) menu.hidden = true;

  for (const def of INCLUDE_DEFS.filter((d) => !d.blockBody)) {
    menu.append(
      el("button", {
        className: "editor-insert-item",
        type: "button",
        role: "menuitem",
        title: def.label,
        onClick: () => {
          const attrs = promptIncludeAttrs(def);
          closeEditorMenus();
          if (state.bodyEditor) state.bodyEditor.insertInclude(def.name, attrs);
          else renderMain();
        },
      }, [
        materialIcon(INCLUDE_ICONS[def.name] || "add", "editor-insert-icon"),
        el("span", { text: def.label }),
      ])
    );
  }

  return el("div", { className: "editor-insert" }, [
    el("button", {
      className: "btn editor-insert-btn",
      type: "button",
      "aria-haspopup": "menu",
      "aria-expanded": state.insertMenuOpen ? "true" : "false",
      title: "Insert a Liquid include block",
      onClick: (e) => {
        e.stopPropagation();
        const next = !state.insertMenuOpen;
        state.insertMenuOpen = next;
        const panel = $("#insert-menu");
        const btn = e.currentTarget;
        if (panel) panel.hidden = !next;
        btn.setAttribute("aria-expanded", next ? "true" : "false");
      },
    }, [
      materialIcon("add"),
      el("span", { text: "Insert" }),
      materialIcon("expand_more", "editor-insert-caret"),
    ]),
    menu,
  ]);
}

function renderAiProofControl() {
  // Two flat buttons, not a dropdown: opening a menu steals focus from the
  // body and clears the selection before Correct/Refine can read it.
  const items = [
    {
      action: "correct",
      label: "Correct",
      icon: "check",
      title: "Spelling, grammar, idiom, and punctuation (selection or full body)",
    },
    {
      action: "refine",
      label: "Refine",
      icon: "edit",
      title: "Clarity and flow (selection or full body), using writing guidelines",
    },
  ];

  return el(
    "div",
    { className: "editor-ai-proof" },
    items.map((item) =>
      el(
        "button",
        {
          className: "btn editor-insert-btn",
          type: "button",
          title: item.title,
          "data-studio-action": item.action,
          disabled: !canAiProof() || state.aiProofBusy,
          onMouseDown: (e) => {
            // Keep the editor focused and snapshot the range before blur.
            e.preventDefault();
            state.aiProofSelection = getBodySelection();
          },
          onClick: () => {
            flashAiProofHint("");
            void startRewrite(item.action);
          },
        },
        [
          materialIcon(item.icon),
          el("span", {
            className: "editor-ai-proof-label",
            text: state.aiProofBusy ? "Working…" : item.label,
          }),
        ]
      )
    )
  );
}

function editorChain() {
  return state.bodyEditor?.editor?.chain().focus();
}

function toolbarBtn(opts) {
  return el("button", {
    className: "editor-toolbar-btn",
    type: "button",
    title: opts.title,
    "aria-label": opts.title,
    onClick: opts.onClick,
  }, [
    opts.icon ? materialIcon(opts.icon) : null,
    opts.text ? el("span", { text: opts.text }) : null,
  ]);
}

function toolbarSep() {
  return el("span", { className: "editor-toolbar-sep", "aria-hidden": "true" });
}

function renderFormatToolbar() {
  const colorSelect = el("select", {
    className: "editor-toolbar-select",
    title: "Text color",
    "aria-label": "Text color",
    onChange: (e) => {
      const chain = editorChain();
      if (!chain) return;
      const value = e.target.value;
      if (!value) chain.unsetColor().run();
      else chain.setColor(value).run();
    },
  });
  for (const c of TEXT_COLORS) {
    colorSelect.append(el("option", { value: c.value, text: c.label }));
  }

  return el("div", {
    className: "editor-format-toolbar",
    role: "toolbar",
    "aria-label": "Formatting",
  }, [
    toolbarBtn({
      title: "Paragraph",
      icon: "notes",
      onClick: () => editorChain()?.setParagraph().run(),
    }),
    toolbarBtn({
      title: "Heading 1",
      text: "H1",
      onClick: () => editorChain()?.toggleHeading({ level: 1 }).run(),
    }),
    toolbarBtn({
      title: "Heading 2",
      text: "H2",
      onClick: () => editorChain()?.toggleHeading({ level: 2 }).run(),
    }),
    toolbarBtn({
      title: "Heading 3",
      text: "H3",
      onClick: () => editorChain()?.toggleHeading({ level: 3 }).run(),
    }),
    toolbarBtn({
      title: "Heading 4",
      text: "H4",
      onClick: () => editorChain()?.toggleHeading({ level: 4 }).run(),
    }),
    toolbarBtn({
      title: "Blockquote",
      icon: "format_quote",
      onClick: () => editorChain()?.toggleBlockquote().run(),
    }),
    toolbarSep(),
    toolbarBtn({
      title: "Bold",
      icon: "format_bold",
      onClick: () => editorChain()?.toggleBold().run(),
    }),
    toolbarBtn({
      title: "Italic",
      icon: "format_italic",
      onClick: () => editorChain()?.toggleItalic().run(),
    }),
    toolbarBtn({
      title: "Strikethrough",
      icon: "format_strikethrough",
      onClick: () => editorChain()?.toggleStrike().run(),
    }),
    toolbarSep(),
    colorSelect,
    toolbarSep(),
    toolbarBtn({
      title: "Lowercase",
      text: "aa",
      onClick: () => state.bodyEditor?.transformSelectionCase("lower"),
    }),
    toolbarBtn({
      title: "Uppercase",
      text: "AA",
      onClick: () => state.bodyEditor?.transformSelectionCase("upper"),
    }),
    toolbarBtn({
      title: "Title case",
      text: "Aa",
      onClick: () => state.bodyEditor?.transformSelectionCase("title"),
    }),
  ]);
}

function coerceBooleanField(value, fallback) {
  if (value === true || value === "true") return true;
  if (value === false || value === "false") return false;
  if (fallback === true || fallback === "true") return true;
  if (fallback === false || fallback === "false") return false;
  return false;
}

function renderField(field, opts = {}) {
  const name = field.name;
  const target = opts.target || state.fields;
  const onChange = opts.onChange || (() => {
    markDirty();
  });
  const value = target[name] ?? field.default ?? "";
  const wrap = el("div", {
    className: "field" + (name === "title" ? " field--title" : ""),
  });
  const inputId = `field-${opts.idPrefix || ""}${name}`;

  // Section name always on its own line (booleans included).
  wrap.append(
    el("label", {
      className: "field-heading",
      text: field.label || name,
      htmlFor: inputId,
    })
  );

  if (field.type === "boolean") {
    const raw = Object.prototype.hasOwnProperty.call(target, name)
      ? target[name]
      : field.default;
    const checked = coerceBooleanField(raw, field.default);
    const box = el("input", {
      id: inputId,
      type: "checkbox",
      className: "field-checkbox",
      checked,
      onChange: (e) => {
        target[name] = !!e.target.checked;
        onChange();
      },
    });
    const hint = fieldHint(field);
    wrap.classList.add("field--boolean");
    wrap.append(
      el("label", { className: "field-check-row", htmlFor: inputId }, [
        box,
        el("span", {
          className: "field-check-text",
          text: hint || "On",
        }),
      ])
    );
    return wrap;
  }

  if (field.type === "select" && field.options?.values) {
    const multiple = !!field.options.multiple;
    const select = el("select", {
      id: inputId,
      multiple,
      onChange: (e) => {
        if (multiple) {
          target[name] = [...e.target.selectedOptions].map((o) => o.value);
        } else {
          target[name] = e.target.value;
        }
        onChange();
      },
    });
    for (const opt of field.options.values) {
      const v = typeof opt === "object" ? opt.value : opt;
      const selected = multiple
        ? String(value).includes(v) || (Array.isArray(value) && value.includes(v))
        : String(value) === String(v);
      select.append(el("option", { value: v, text: v, selected }));
    }
    wrap.append(select);
  } else if (field.type === "object" && field.list) {
    if (!Array.isArray(target[name])) target[name] = Array.isArray(value) ? value : [];
    wrap.append(
      renderObjectListEditor(field, target[name], {
        onChange: (next) => {
          target[name] = next;
          markDirty();
          renderShell();
        },
        idPrefix: `${opts.idPrefix || ""}${name}-`,
      })
    );
  } else if (field.list && (field.type === "string" || !field.type)) {
    const textValue = Array.isArray(value) ? value.join("\n") : String(value || "");
    wrap.append(
      el("textarea", {
        id: inputId,
        text: textValue,
        placeholder: "One item per line",
        onInput: (e) => {
          target[name] = e.target.value
            .split("\n")
            .map((s) => s.trim())
            .filter(Boolean);
          onChange();
        },
      })
    );
  } else if (field.type === "text" || field.type === "image") {
    wrap.append(
      el(field.type === "text" ? "textarea" : "input", {
        id: inputId,
        type: field.type === "image" ? "url" : undefined,
        value: value,
        text: field.type === "text" ? value : undefined,
        placeholder:
          field.type === "image"
            ? "https://… or /media/images/…"
            : undefined,
        onInput: (e) => {
          target[name] = e.target.value;
          onChange();
        },
      })
    );
  } else {
    wrap.append(
      el("input", {
        id: inputId,
        type: field.type === "number" ? "number" : field.type === "date" ? "date" : "text",
        value: value,
        onInput: (e) => {
          target[name] = e.target.value;
          onChange();
        },
      })
    );
  }

  if (field.description) {
    const hint = fieldHint(field);
    if (hint) wrap.append(el("p", { className: "hint", text: hint }));
  }
  return wrap;
}

/** Nested list-of-objects (e.g. skills.technical). Mutates the live array. */
function renderObjectListEditor(field, items, { onChange, idPrefix }) {
  const list = Array.isArray(items) ? items : [];
  const host = el("div", { className: "yaml-object-list" });
  const commitStructural = (next) => {
    onChange(next, { structural: true });
  };

  list.forEach((raw, index) => {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
      list[index] = {};
    }
    const item = list[index];
    const card = el("div", { className: "yaml-list-item" });
    card.append(
      el("div", { className: "yaml-list-item-head" }, [
        el("span", {
          className: "yaml-list-item-index",
          text: `${field.label || field.name} ${index + 1}`,
        }),
        el("div", { className: "yaml-list-item-actions" }, [
          el("button", {
            className: "btn yaml-list-btn",
            type: "button",
            text: "↑",
            title: "Move up",
            disabled: index === 0,
            onClick: () => {
              if (index === 0) return;
              const next = [...list];
              [next[index - 1], next[index]] = [next[index], next[index - 1]];
              commitStructural(next);
            },
          }),
          el("button", {
            className: "btn yaml-list-btn",
            type: "button",
            text: "↓",
            title: "Move down",
            disabled: index === list.length - 1,
            onClick: () => {
              if (index >= list.length - 1) return;
              const next = [...list];
              [next[index], next[index + 1]] = [next[index + 1], next[index]];
              commitStructural(next);
            },
          }),
          el("button", {
            className: "btn yaml-list-btn",
            type: "button",
            text: "Remove",
            onClick: () => {
              commitStructural(list.filter((_, i) => i !== index));
            },
          }),
        ]),
      ])
    );
    const sub = el("div", { className: "form-grid yaml-list-item-fields" });
    for (const subField of field.fields || []) {
      if (subField.hidden) continue;
      sub.append(
        renderField(subField, {
          target: item,
          idPrefix: `${idPrefix}${index}-`,
          onChange: () => {
            markDirty();
          },
        })
      );
    }
    card.append(sub);
    host.append(card);
  });

  host.append(
    el("button", {
      className: "btn",
      type: "button",
      text: `Add ${field.label || "item"}`,
      onClick: () => {
        commitStructural([...list, emptyItemFromFields(field.fields || [])]);
      },
    })
  );
  return host;
}

function renderPreviewPane() {
  const width =
    typeof window !== "undefined" && window.innerWidth
      ? `${Math.round(window.innerWidth)}px`
      : "";
  const metaParts = [el("span", { className: "preview-pane-label", text: "Preview" })];
  if (width) {
    metaParts.push(
      el("span", { className: "preview-pane-sep", "aria-hidden": "true", text: "·" }),
      el("span", {
        className: "preview-pane-meta",
        text: `Viewport ${width}`,
      })
    );
  }
  return el("div", { className: "pane pane-preview" }, [
    el("div", { className: "preview-pane-head" }, metaParts),
    el("div", {
      className: "preview-folio",
    }, [
      el("div", {
        className: "preview-frame",
        id: "preview-frame",
        html: state.previewHtml,
      }),
    ]),
  ]);
}

function mountBodyEditor() {
  const host = $("#tiptap-host");
  if (!host) return;
  destroyBodyEditor();

  // Preview tab keeps the Visual surface mounted on wide screens; skip TipTap on Source.
  if (state.bodyMode === "source") {
    host.hidden = true;
    return;
  }
  host.hidden = false;

  const content =
    state.bodyMode === "preview" && state.lastEditorMode === "source"
      ? state.body
      : state.body;

  state.bodyEditor = createBodyEditor(host, {
    content,
    onUpdate: (md) => {
      state.body = md;
      markDirty();
      refreshPreview();
    },
  });
}

function syncBodyFromEditor() {
  let next = null;
  if (state.bodyEditor && state.bodyMode !== "source") {
    next = state.bodyEditor.getMarkdown();
  }
  const source = $("#body-source");
  if (source && state.bodyMode === "source") {
    next = source.value;
  }
  if (next == null) return;
  const loaded = state.baseline?.body;
  if (typeof loaded === "string" && next === roundTripMarkdown(loaded)) {
    state.body = loaded;
    return;
  }
  state.body = next;
}

function destroyBodyEditor() {
  if (state.bodyEditor) {
    state.bodyEditor.destroy();
    state.bodyEditor = null;
  }
}

/** Debounced cite/xcite existence for side-preview pills (neutral → green/red). */
const citeLookupTimers = new Map();
const citeLookupStatus = new Map();
const CITE_LOOKUP_MS = 1000;

async function citeKeyExists(kind, key) {
  const q = String(key || "").trim();
  if (!q) return false;
  try {
    const data =
      kind === "xcite"
        ? await studioApi.searchXcite(q)
        : await studioApi.searchCite(q);
    const results = data?.results || [];
    const needle = q.toLowerCase();
    return results.some(
      (r) => String(r.key || "").trim().toLowerCase() === needle
    );
  } catch {
    return false;
  }
}

function paintCitePill(el, status) {
  el.classList.remove("studio-ref-pill--ok", "studio-ref-pill--missing");
  if (status === "ok") el.classList.add("studio-ref-pill--ok");
  else if (status === "missing") el.classList.add("studio-ref-pill--missing");
}

function scheduleCiteLookups(frame) {
  if (!frame) return;
  const present = new Set();
  const byId = new Map();

  for (const el of frame.querySelectorAll("[data-cite-check]")) {
    const kind = el.getAttribute("data-cite-check") || "cite";
    const key = String(el.getAttribute("data-key") || "").trim();
    const id = `${kind}:${key}`;
    present.add(id);
    if (!byId.has(id)) byId.set(id, []);
    byId.get(id).push(el);

    if (!key) {
      paintCitePill(el, "missing");
      continue;
    }

    const known = citeLookupStatus.get(id);
    if (known === "ok" || known === "missing") {
      paintCitePill(el, known);
    } else {
      paintCitePill(el, null);
    }
  }

  for (const id of [...citeLookupStatus.keys()]) {
    if (!present.has(id)) {
      citeLookupStatus.delete(id);
      const t = citeLookupTimers.get(id);
      if (t) clearTimeout(t);
      citeLookupTimers.delete(id);
    }
  }

  for (const [id, els] of byId) {
    const key = id.slice(id.indexOf(":") + 1);
    const kind = id.startsWith("xcite:") ? "xcite" : "cite";
    if (!key) continue;
    if (citeLookupStatus.get(id) === "ok" || citeLookupStatus.get(id) === "missing") {
      continue;
    }
    // Do not restart the timer on unrelated body edits — only on new/changed keys.
    if (citeLookupTimers.has(id)) continue;
    citeLookupTimers.set(
      id,
      setTimeout(async () => {
        citeLookupTimers.delete(id);
        const exists = await citeKeyExists(kind, key);
        const status = exists ? "ok" : "missing";
        citeLookupStatus.set(id, status);
        const root = $("#preview-frame");
        if (!root) return;
        for (const el of root.querySelectorAll(
          `[data-cite-check="${kind}"][data-key="${CSS.escape(key)}"]`
        )) {
          paintCitePill(el, status);
        }
        void els;
      }, CITE_LOOKUP_MS)
    );
  }
}

function refreshPreview() {
  const frame = $("#preview-frame");
  if (isYamlCollection()) {
    state.previewHtml = renderYamlPreviewHtml();
  } else {
    state.previewHtml = renderPreview(state.body || "");
  }
  if (frame) {
    // innerHTML wipe resets scroll; keep the reader's place while typing.
    const scrollTop = frame.scrollTop;
    const scrollLeft = frame.scrollLeft;
    frame.innerHTML = state.previewHtml;
    frame.scrollTop = scrollTop;
    frame.scrollLeft = scrollLeft;
    if (!isYamlCollection()) {
      scheduleCiteLookups(frame);
      void Promise.resolve(mountMermaidPreview(frame)).then(() => {
        // Mermaid layout can shift height after the sync restore above.
        if ($("#preview-frame") === frame) {
          frame.scrollTop = scrollTop;
          frame.scrollLeft = scrollLeft;
        }
      });
    }
  }
}

function escapePreviewText(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function renderYamlPreviewHtml() {
  const col = state.collection;
  const kind = yamlEditKind(col);
  let text = "";
  try {
    if (state.yamlUiMode === "source" || kind === "source") {
      text = state.body || "";
    } else if (kind === "list") {
      text = dumpYaml(state.yamlList || []);
    } else if (kind === "map" && col.root_key) {
      const doc =
        state.yamlDoc && typeof state.yamlDoc === "object"
          ? { ...state.yamlDoc }
          : {};
      doc[col.root_key] = pruneEmptyFields({ ...state.fields }, col.fields);
      text = dumpYaml(doc);
    } else if (kind === "map") {
      text = dumpYaml(pruneEmptyFields({ ...state.fields }, col.fields));
    } else {
      text = state.body || "";
    }
  } catch (err) {
    return `<p class="yaml-preview-error">${escapePreviewText(err.message || err)}</p>`;
  }
  return `<pre class="yaml-preview-pre">${escapePreviewText(text)}</pre>`;
}

let mermaidLoader = null;

function loadMermaid() {
  if (window.mermaid) return Promise.resolve(window.mermaid);
  if (mermaidLoader) return mermaidLoader;
  mermaidLoader = import("https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs")
    .then((mod) => {
      const mermaid = mod.default;
      window.mermaid = mermaid;
      mermaid.initialize({
        startOnLoad: false,
        theme: document.documentElement.getAttribute("data-theme") === "dark" ? "dark" : "default",
        securityLevel: "strict",
      });
      return mermaid;
    })
    .catch((err) => {
      mermaidLoader = null;
      throw err;
    });
  return mermaidLoader;
}

function mermaidFallback(node, message) {
  const source = node.dataset.mermaidSource || node.textContent || "";
  node.dataset.mermaidSource = source;
  node.className = "studio-mermaid-fallback";
  node.removeAttribute("data-processed");
  const errLine = message ? `Mermaid: ${message}\n\n` : "Mermaid (unrendered)\n\n";
  node.innerHTML = "";
  const pre = document.createElement("pre");
  pre.className = "studio-mermaid-fallback__pre";
  pre.textContent = errLine + source;
  node.append(pre);
}

/** Convert ```mermaid fences to diagrams; boxed monospace fallback on failure. */
async function mountMermaidPreview(root) {
  if (!root) return;
  const nodes = [];
  root.querySelectorAll("pre code.language-mermaid").forEach((code) => {
    const source = code.textContent || "";
    const div = document.createElement("div");
    div.className = "mermaid studio-mermaid";
    div.dataset.mermaidSource = source;
    div.textContent = source;
    const pre = code.closest("pre");
    if (pre) pre.replaceWith(div);
    else code.replaceWith(div);
    nodes.push(div);
  });
  root
    .querySelectorAll(".mermaid[data-mermaid-source], .studio-mermaid-fallback[data-mermaid-source]")
    .forEach((node) => {
      if (!nodes.includes(node)) nodes.push(node);
    });
  if (!nodes.length) return;

  let mermaid;
  try {
    mermaid = await loadMermaid();
  } catch (err) {
    for (const node of nodes) {
      mermaidFallback(node, err?.message || "failed to load Mermaid");
    }
    return;
  }

  mermaid.initialize({
    startOnLoad: false,
    theme: document.documentElement.getAttribute("data-theme") === "dark" ? "dark" : "default",
    securityLevel: "strict",
  });

  for (const node of nodes) {
    const source = node.dataset.mermaidSource || "";
    node.className = "mermaid studio-mermaid";
    node.removeAttribute("data-processed");
    node.innerHTML = "";
    node.textContent = source;
  }

  try {
    await mermaid.run({ nodes });
  } catch (err) {
    for (const node of nodes) {
      if (!node.querySelector("svg")) {
        mermaidFallback(node, err?.message || "render failed");
      }
    }
  }

  for (const node of nodes) {
    if (node.classList.contains("studio-mermaid-fallback")) continue;
    if (!node.querySelector("svg")) {
      mermaidFallback(node, "render produced no diagram");
    }
  }
}

function isWritingCollection(col = state.collection) {
  const name = col?.name;
  return name === "articles" || name === "posts";
}

/** Front-matter `published`; missing/true → published (export default). */
function entryIsPublished(item) {
  const v = item?.published;
  if (v === false || v === "false") return false;
  return true;
}

function publishStatusPill(item) {
  const published = entryIsPublished(item);
  return el("span", {
    className:
      "ledger-status " +
      (published ? "ledger-status--published" : "ledger-status--draft"),
    text: published ? "Published" : "Draft",
    title: published ? "Published (exported)" : "Draft (excluded from export)",
  });
}

async function selectCollection(col) {
  destroyBodyEditor();
  state.mediaOpen = false;
  state.mediaItems = [];
  state.collection = col;
  state.file = null;
  state.baseline = null;
  state.frontMatterOpen = null;
  state.items = [];
  state.insertMenuOpen = false;
  closeNavMenu();
  clearError();
  state.listLoading = col.type !== "file";
  state.fileLoading = col.type === "file";
  state.status = `Loading ${col.label}…`;
  renderShell();
  try {
    if (col.type === "file") {
      await openFile(col.path);
      return;
    }
    const cached = cachedTreeItems(col);
    if (cached) {
      state.items = cached;
      rememberNavCount(col, cached.length);
      state.listLoading = false;
      state.status = "";
      renderShell();
      return;
    }
    const data = await studioApi.tree(col.path);
    state.items = data.items || [];
    rememberTree(col, state.items);
    state.listLoading = false;
    // Entry count lives beside the list title — do not repeat it in the toolbar.
    state.status = "";
  } catch (err) {
    state.items = [];
    state.listLoading = false;
    captureError(err);
  }
  renderShell();
}

async function openFile(path) {
  destroyBodyEditor();
  state.insertMenuOpen = false;
  state.fileLoading = true;
  state.file = null;
  state.baseline = null;
  state.frontMatterOpen = null;
  state.status = `Opening ${path}…`;
  clearError();
  state.yamlDoc = null;
  state.yamlList = null;
  renderShell();
  try {
    const data = await studioApi.getFile(path);
    state.file = path;
    state.sha = data.sha;
    const split = splitDocument(data.content);
    const col = state.collection;
    if (col.format === "yaml") {
      state.body = data.content;
      const kind = yamlEditKind(col);
      if (kind === "list") {
        const doc = loadYaml(data.content);
        state.yamlList = asObjectList(doc);
        state.fields = {};
        state.yamlDoc = null;
        state.yamlUiMode = "structured";
      } else if (kind === "map") {
        if (col.root_key) {
          const doc = asObjectMap(loadYaml(data.content));
          state.yamlDoc = doc;
          state.fields = asObjectMap(doc[col.root_key]);
        } else {
          state.yamlDoc = null;
          state.fields = asObjectMap(loadYaml(data.content));
        }
        state.yamlList = null;
        state.yamlUiMode = "structured";
      } else {
        state.fields = {};
        state.yamlList = null;
        state.yamlUiMode = "source";
      }
    } else if (col.format === "raw") {
      state.body = data.content;
      state.fields = {};
    } else {
      state.fields = { ...split.fm };
      state.body = split.body;
    }
    state.dirty = false;
    state.fileLoading = false;
    state.listLoading = false;
    state.status = path;
    captureBaseline();
  } catch (err) {
    state.fileLoading = false;
    state.listLoading = false;
    state.baseline = null;
    captureError(err);
  }
  renderShell();
}

/** Deep-ish snapshot of the current entry for Discard. */
function captureBaseline() {
  state.baseline = {
    fields: structuredClone(state.fields || {}),
    body: state.body,
    yamlDoc: state.yamlDoc ? structuredClone(state.yamlDoc) : null,
    yamlList: state.yamlList ? structuredClone(state.yamlList) : null,
    yamlUiMode: state.yamlUiMode,
    sha: state.sha,
  };
}

/** Revert the open entry to the last loaded / saved baseline; stay on the page. */
function discardChanges() {
  if (!state.file || !state.baseline) return;
  const b = state.baseline;
  destroyBodyEditor();
  state.fields = structuredClone(b.fields || {});
  state.body = b.body;
  state.yamlDoc = b.yamlDoc ? structuredClone(b.yamlDoc) : null;
  state.yamlList = b.yamlList ? structuredClone(b.yamlList) : null;
  state.yamlUiMode = b.yamlUiMode || "structured";
  state.sha = b.sha;
  state.dirty = false;
  state.insertMenuOpen = false;
  if (state.bodyMode === "preview") {
    /* keep preview tab */
  } else if (state.bodyMode !== "visual" && state.bodyMode !== "source") {
    state.bodyMode = state.lastEditorMode || "visual";
  }
  clearError();
  state.status = `Reverted ${state.file}`;
  renderShell();
}

async function reexportLocalContent() {
  if (state.reexporting) return;
  state.reexporting = true;
  state.pipeline.state = "syncing";
  state.pipeline.message = "";
  state.status = "Reexporting…";
  clearError();
  renderShell();
  try {
    const res = await fetch("/__dev/reexport", {
      method: "POST",
      headers: { Accept: "application/json" },
    });
    let data = {};
    try {
      data = await res.json();
    } catch {
      data = {};
    }
    if (!res.ok || !data.ok) {
      throw new Error((data && data.error) || `Export failed: ${res.status}`);
    }
    state.pipeline.state = "ok";
    state.status = "Reexported — reloading…";
    renderShell();
    setTimeout(() => {
      try {
        const url = new URL(window.location.href);
        url.searchParams.set("_refresh", String(Date.now()));
        window.location.replace(url.toString());
      } catch {
        window.location.reload();
      }
    }, 200);
  } catch (err) {
    state.pipeline.state = "error";
    state.pipeline.message = String(err.message || err);
    captureError(err);
    renderShell();
  } finally {
    state.reexporting = false;
  }
}

async function createNewEntry() {
  const col = state.collection;
  if (!collectionAllowsCreate(col)) return;
  const raw = window.prompt(`New ${col.label || "entry"} key (slug):`);
  if (raw == null) return;
  const key = sanitizeEntryKey(raw);
  if (!key) {
    state.error = "Key must use letters, numbers, or hyphens.";
    state.errorDetail = "";
    renderShell();
    return;
  }
  const filename = expandFilenamePattern(col.filename, key);
  const path = `${String(col.path || "").replace(/\/$/, "")}/${filename}`;

  const fields = emptyItemFromFields(col.fields || []);
  for (const field of col.fields || []) {
    if (
      field?.hidden &&
      field.name &&
      Object.prototype.hasOwnProperty.call(field, "default")
    ) {
      fields[field.name] = field.default;
    }
  }
  fields.key = key;
  if (!fields.title) fields.title = key;
  if (String(col.filename || "").includes("{year}") && !fields.date) {
    fields.date = todayIsoDate();
  }

  let content;
  if (col.format === "yaml") {
    content = dumpYaml(pruneEmptyFields({ ...fields }, col.fields));
  } else {
    content = rebuildDocument("---\n---\n\n", {
      fields,
      body: "\n",
      format: col.format || "yaml-frontmatter",
    });
  }
  if (!content.endsWith("\n")) content += "\n";

  state.status = `Creating ${path}…`;
  clearError();
  renderShell();
  try {
    let exists = false;
    try {
      await studioApi.getFile(path);
      exists = true;
    } catch (err) {
      if (err.status !== 404 && err.code !== "not_found") throw err;
    }
    if (exists) throw new Error(`${path} already exists`);

    const created = await studioApi.putFile({
      path,
      content,
      sha: null,
      message: `studio: create ${path}`,
    });
    invalidateTreeCache(col.name);
    state.status = `Created ${path}`;
    armPipelineWatch(created?.commit);
    await selectCollection(col);
    await openFile(path);
  } catch (err) {
    captureError(err);
    renderShell();
  }
}

async function deleteEntry(path, sha = null) {
  const col = state.collection;
  if (!collectionAllowsDelete(col) || !path) return;
  const name = String(path).split("/").pop() || path;
  if (!window.confirm(`Delete ${name}?\n\nThis commits a deletion to main and cannot be undone from Studio.`)) {
    return;
  }
  state.status = `Deleting ${path}…`;
  clearError();
  renderShell();
  try {
    let fileSha = sha;
    if (!fileSha) {
      const data = await studioApi.getFile(path);
      fileSha = data.sha;
    }
    const deleted = await studioApi.deleteFile({
      path,
      sha: fileSha,
      message: `studio: delete ${path}`,
    });
    invalidateTreeCache(col?.name);
    if (state.file === path) {
      destroyBodyEditor();
      state.file = null;
      state.baseline = null;
      state.sha = null;
      state.dirty = false;
      state.fields = {};
      state.body = "";
    }
    state.status = `Deleted ${path}`;
    armPipelineWatch(deleted?.commit);
    if (col) await selectCollection(col);
    else renderShell();
  } catch (err) {
    captureError(err);
    renderShell();
  }
}

async function deleteCurrentEntry() {
  if (!state.file) return;
  await deleteEntry(state.file, state.sha);
}

async function saveCurrent() {
  if (!state.file || state.saving) return;
  syncBodyFromEditor();
  if (isYamlCollection()) {
    const source = $("#yaml-source");
    if (source) state.body = source.value;
  }
  state.saving = true;
  state.status = "Saving…";
  clearError();
  renderShell();
  try {
    let content;
    const col = state.collection;
    if (col.format === "raw") {
      content = state.body;
    } else if (col.format === "yaml") {
      const kind = yamlEditKind(col);
      const useSource =
        state.yamlUiMode === "source" || kind === "source";
      if (useSource) {
        // Validate before commit so we do not push broken YAML.
        loadYaml(state.body);
        content = state.body.endsWith("\n") ? state.body : state.body + "\n";
      } else if (kind === "list") {
        content = dumpYaml(state.yamlList || []);
      } else if (kind === "map" && col.root_key) {
        const doc =
          state.yamlDoc && typeof state.yamlDoc === "object"
            ? { ...state.yamlDoc }
            : {};
        doc[col.root_key] = pruneEmptyFields(
          { ...state.fields },
          col.fields
        );
        content = dumpYaml(doc);
      } else if (kind === "map") {
        content = dumpYaml(
          pruneEmptyFields({ ...state.fields }, col.fields)
        );
      } else {
        content = state.body.endsWith("\n") ? state.body : state.body + "\n";
      }
    } else {
      const original = (await studioApi.getFile(state.file)).content;
      const fields = { ...state.fields };
      content = rebuildDocument(original, {
        fields,
        body: state.body,
        format: col.format,
      });
    }
    if (!content.endsWith("\n")) content += "\n";
    const result = await studioApi.putFile({
      path: state.file,
      content,
      sha: state.sha,
      message: `studio: update ${state.file}`,
    });
    state.sha = result.content?.sha || state.sha;
    state.dirty = false;
    clearError();
    state.status = `Saved ${state.file}`;
    captureBaseline();
    // List thumbs/titles may have changed — drop session tree for this collection.
    if (col?.name) invalidateTreeCache(col.name);
    armPipelineWatch(result?.commit);
  } catch (err) {
    captureError(err);
  } finally {
    state.saving = false;
    renderShell();
  }
}

async function bootApp(clerk) {
  try {
    state.session = await studioApi.session();
  } catch (err) {
    const code = err?.data?.error || "";
    if (code === "not_allowlisted") {
      renderPendingReviewGate(clerk, err?.data?.email || clerkUserEmail(clerk));
      return;
    }
    state.error = `Session failed: ${err.message}`;
    renderAuthGate(clerk);
    if (state.error) {
      app.append(el("p", { className: "status-pill error", text: state.error }));
    }
    return;
  }

  try {
    state.schema = await loadSchema();
  } catch (err) {
    state.error = String(err.message || err);
    app.innerHTML = "";
    app.append(el("p", { className: "auth-gate status-pill error", text: state.error }));
    return;
  }

  renderShell();
  void refreshPipelineStatus();

  scheduleTreePrefetch();

  if (clerk && !clerk.dev && clerk.addListener) {
    clerk.addListener(({ user }) => {
      if (!user) {
        destroyBodyEditor();
        renderAuthGate(clerk);
      }
    });
  }
}

async function main() {
  initTheme();
  const clerk = await initClerk();

  if (clerk.dev) {
    await bootApp(clerk);
    return;
  }

  if (clerk.user) {
    await bootApp(clerk);
  } else {
    renderAuthGate(clerk);
    clerk.addListener(async ({ user }) => {
      if (user) await bootApp(clerk);
    });
  }
}

main().catch((err) => {
  app.textContent = String(err.stack || err);
});
