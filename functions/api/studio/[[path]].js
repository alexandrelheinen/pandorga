/**
 * Studio API — Cloudflare Pages Function.
 * Spec: docs/features/studio.md §5 (AC-STU-01, AC-STU-02, AC-STU-09).
 */

import { verifyClerkRequest } from "./_lib/auth.js";
import {
  getFile,
  putFile,
  deleteFile,
  putBinaryFile,
  getFileMeta,
  listDir,
  listEntries,
  peekMeta,
  getContentPipelineStatus,
} from "./_lib/github.js";
import { normalizeRepoPath, listSchemaCollections } from "./_lib/paths.js";
import { clientAddress, isMutatingMethod, takeToken } from "./_lib/rate-limit.js";
import { rewriteRateLimit, runRewrite } from "./_lib/rewrite.js";

const WRITE_RATE = new Map();
const WRITE_WINDOW_MS = 60_000;
const WRITE_MAX = 60;

/** Soft cap under GitHub Contents API 100 MB hard limit (base64 JSON body). */
const MAX_MEDIA_BYTES = 25 * 1024 * 1024;
const MEDIA_ROOT = "content/media";
const SAFE_SEGMENT = /^[A-Za-z0-9][A-Za-z0-9._-]*$/;

/** Bound per-request in onRequest so corsHeaders/json stay signature-stable. */
let requestEnv = {};

function allowedOrigins() {
  const fromEnv = String(requestEnv.STUDIO_ALLOWED_ORIGINS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  // Local wrangler / jekyll serve always allowed; production must set the list.
  return new Set([
    ...fromEnv,
    "http://localhost:4000",
    "http://127.0.0.1:4000",
    "http://localhost:8788",
    "http://127.0.0.1:8788",
  ]);
}

function corsHeaders(request) {
  const origin = request.headers.get("Origin") || "";
  const allow =
    !origin ||
    origin.includes("localhost") ||
    origin.includes("127.0.0.1") ||
    allowedOrigins().has(origin);
  return {
    "Access-Control-Allow-Origin": allow ? origin || "*" : "null",
    "Access-Control-Allow-Headers": "Authorization, Content-Type",
    "Access-Control-Allow-Methods": "GET, PUT, POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
  };
}

function json(data, status, request, extraHeaders) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...corsHeaders(request),
      ...(extraHeaders || {}),
    },
  });
}

/**
 * Spec §4 throttles mutating routes. Counting every GET (tree prefetch, open,
 * cite search) shared one 60/min bucket with Save, so a normal editing
 * session returned `rate_limited` on the commit.
 */
function tooManyChanges(request, userId) {
  const decision = takeToken(
    WRITE_RATE,
    `${userId}:${clientAddress(request)}`,
    Date.now(),
    { windowMs: WRITE_WINDOW_MS, max: WRITE_MAX }
  );
  if (decision.allowed) return null;
  return json(
    {
      error: "rate_limited",
      message: "Too many changes in a short time. Wait a minute, then save again.",
    },
    429,
    request,
    { "Retry-After": String(decision.retryAfterSec) }
  );
}

async function loadSchema(env) {
  // Prefer in-repo schema via GitHub so the Function does not ship a stale copy.
  try {
    const file = await getFile(env, "studio/schema.yml");
    if (file?.content) {
      return parseMinimalYamlCollections(file.content);
    }
  } catch {
    /* fall through */
  }
  return { content: [] };
}

/** Tiny YAML subset sufficient for tree routing (name/path/type nesting). */
function parseMinimalYamlCollections(text) {
  // For tree listing we only need collection path map; the SPA ships full schema.
  // Keep Function free of a YAML dependency: SPA sends collection path, we validate prefix.
  void text;
  return { content: [] };
}

function routeParts(context) {
  const raw = context.params.path;
  if (Array.isArray(raw)) return raw.filter(Boolean);
  if (typeof raw === "string" && raw.length) return raw.split("/").filter(Boolean);
  return [];
}

export async function onRequestOptions(context) {
  requestEnv = context.env || {};
  return new Response(null, { status: 204, headers: corsHeaders(context.request) });
}

export async function onRequest(context) {
  const { request, env } = context;
  requestEnv = env || {};
  if (request.method === "OPTIONS") {
    return onRequestOptions(context);
  }

  const auth = await verifyClerkRequest(request, env);
  if (auth.error) {
    const body = { error: auth.error };
    if (auth.email) body.email = auth.email;
    if (auth.userId) body.userId = auth.userId;
    return json(body, auth.status || 401, request);
  }
  if (isMutatingMethod(request.method)) {
    const limited = tooManyChanges(request, auth.userId);
    if (limited) return limited;
  }

  const parts = routeParts(context);
  const head = parts[0] || "";

  try {
    if (head === "session" && request.method === "GET") {
      return json(
        { userId: auth.userId, email: auth.email || null, bypass: !!auth.bypass },
        200,
        request
      );
    }

    // Content-pipeline status for the commit SHA returned by Save (Actions read).
    if (head === "pipeline-status" && request.method === "GET") {
      const url = new URL(request.url);
      const sha = String(url.searchParams.get("sha") || "").trim();
      const override = String(url.searchParams.get("workflow") || "").trim();
      const statusEnv = override
        ? { ...env, STUDIO_CONTENT_WORKFLOW: override }
        : env;
      try {
        const status = await getContentPipelineStatus(statusEnv, sha);
        return json(status, 200, request);
      } catch (err) {
        const status = err.status || 500;
        return json(
          {
            error: err.code || "server_error",
            message: String(err.message || err),
            detail: err.detail ? String(err.detail).slice(0, 400) : undefined,
          },
          status,
          request
        );
      }
    }

    if (head === "tree" && request.method === "GET") {
      const url = new URL(request.url);
      const collectionPath = normalizeRepoPath(url.searchParams.get("path") || "");
      if (!collectionPath) {
        return json({ error: "invalid_path" }, 400, request);
      }
      // Collection roots are directories under content/
      if (!collectionPath.startsWith("content/")) {
        return json({ error: "invalid_path" }, 400, request);
      }
      const entries = await listDir(env, collectionPath);
      const files = entries
        .filter((e) => /\.(md|markdown|yml|yaml)$/i.test(e.name))
        .slice(0, 500);
      // YAML cite keys (bibliography): list from directory only — per-file getFile
      // on hundreds of entries times out / rate-limits (N+1 Contents API).
      const yamlOnly = files.length > 0 && files.every((e) => /\.ya?ml$/i.test(e.name));
      const items = [];
      if (yamlOnly) {
        for (const entry of files) {
          const stem = entry.name.replace(/\.ya?ml$/i, "");
          items.push({
            path: entry.path,
            name: entry.name,
            title: stem,
            date: null,
            start_date: null,
            end_date: null,
            start: null,
            end: null,
            thumbnail: null,
            key: stem,
            published: null,
            language: null,
            category: null,
            type: null,
            company: null,
            status: null,
            engagement: null,
            tags: null,
            sha: entry.sha,
          });
        }
        items.sort((a, b) => String(a.name).localeCompare(String(b.name)));
      } else {
        // Markdown: peek front matter in small parallel batches.
        const CONCURRENCY = 8;
        for (let i = 0; i < files.length; i += CONCURRENCY) {
          const batch = files.slice(i, i + CONCURRENCY);
          const peeked = await Promise.all(
            batch.map(async (entry) => {
              let meta = {};
              try {
                const file = await getFile(env, entry.path);
                meta = peekMeta(file.content);
              } catch {
                meta = {};
              }
              return {
                path: entry.path,
                name: entry.name,
                title: meta.title || entry.name,
                date: meta.date,
                start_date: meta.start_date,
                end_date: meta.end_date,
                start: meta.start,
                end: meta.end,
                thumbnail: meta.thumbnail,
                key: meta.key,
                published: meta.published,
                language: meta.language,
                category: meta.category,
                type: meta.type,
                company: meta.company,
                status: meta.status,
                engagement: meta.engagement,
                tags: meta.tags,
                sha: entry.sha,
              };
            })
          );
          items.push(...peeked);
        }
        items.sort((a, b) => String(b.date || "").localeCompare(String(a.date || "")));
      }
      return json({ items }, 200, request);
    }

    if (head === "file" && request.method === "GET") {
      const url = new URL(request.url);
      const path = normalizeRepoPath(url.searchParams.get("path") || "");
      if (!path) return json({ error: "invalid_path" }, 400, request);
      const file = await getFile(env, path);
      if (!file) return json({ error: "not_found" }, 404, request);
      const parsed = splitFrontMatter(file.content);
      return json(
        {
          path: file.path,
          sha: file.sha,
          content: file.content,
          front_matter: parsed.frontMatter,
          body: parsed.body,
        },
        200,
        request
      );
    }

    if (head === "file" && request.method === "PUT") {
      const body = await request.json();
      const path = normalizeRepoPath(body.path || "");
      if (!path) return json({ error: "invalid_path" }, 400, request);
      if (typeof body.content !== "string") {
        return json({ error: "content_required" }, 400, request);
      }
      let sha = body.sha || null;
      if (!sha) {
        const existing = await getFile(env, path);
        sha = existing?.sha || null;
      }
      const result = await putFile(env, {
        path,
        content: body.content,
        message: body.message,
        sha,
      });
      return json(
        {
          ok: true,
          path,
          commit: result.commit?.sha || null,
          content: result.content || null,
        },
        200,
        request
      );
    }

    if (head === "file" && request.method === "DELETE") {
      const body = await request.json();
      const path = normalizeRepoPath(body.path || "");
      if (!path) return json({ error: "invalid_path" }, 400, request);
      let sha = body.sha || null;
      if (!sha) {
        const existing = await getFileMeta(env, path);
        sha = existing?.sha || null;
      }
      if (!sha) return json({ error: "not_found" }, 404, request);
      const result = await deleteFile(env, {
        path,
        message: body.message,
        sha,
      });
      return json(
        {
          ok: true,
          path,
          commit: result.commit?.sha || null,
        },
        200,
        request
      );
    }

    if (head === "media" && request.method === "GET") {
      const url = new URL(request.url);
      const rawPath = url.searchParams.get("path") || MEDIA_ROOT;
      const dirPath = normalizeMediaDir(rawPath);
      if (!dirPath) {
        return json({ error: "invalid_media_path" }, 400, request);
      }
      const entries = await listEntries(env, dirPath);
      const items = entries
        .filter((e) => e.name !== ".gitkeep")
        .map((e) => ({
          name: e.name,
          path: e.path,
          type: e.type,
          size: e.size,
          sha: e.sha,
          public_path: e.type === "file" ? publicMediaPath(e.path) : null,
        }))
        .sort((a, b) => {
          if (a.type !== b.type) return a.type === "dir" ? -1 : 1;
          return String(a.name).localeCompare(String(b.name));
        });
      return json(
        {
          root: MEDIA_ROOT,
          path: dirPath,
          public_root: "/media",
          items,
        },
        200,
        request
      );
    }

    if (head === "media" && parts[1] === "folder" && request.method === "POST") {
      const body = await request.json();
      const dirPath = normalizeMediaDir(body.path || "");
      if (!dirPath || dirPath === MEDIA_ROOT) {
        return json({ error: "invalid_media_path" }, 400, request);
      }
      const keepPath = `${dirPath}/.gitkeep`;
      const existing = await getFileMeta(env, keepPath);
      if (existing) {
        return json(
          { ok: true, path: dirPath, public_path: publicMediaPath(dirPath), existed: true },
          200,
          request
        );
      }
      const result = await putFile(env, {
        path: keepPath,
        content: "\n",
        message: body.message || `studio: mkdir ${dirPath}`,
        sha: null,
      });
      return json(
        {
          ok: true,
          path: dirPath,
          public_path: publicMediaPath(dirPath),
          commit: result.commit?.sha || null,
          existed: false,
        },
        200,
        request
      );
    }

    if (head === "media" && request.method === "POST") {
      const body = await request.json();
      const path = normalizeMediaFile(body.path || "");
      if (!path) {
        return json({ error: "invalid_media_path" }, 400, request);
      }
      if (typeof body.content_base64 !== "string" || !body.content_base64) {
        return json({ error: "content_base64_required" }, 400, request);
      }
      let byteLength = 0;
      try {
        byteLength = Math.floor((body.content_base64.replace(/\s/g, "").length * 3) / 4);
      } catch {
        return json({ error: "invalid_base64" }, 400, request);
      }
      if (byteLength > MAX_MEDIA_BYTES) {
        return json(
          {
            error: "file_too_large",
            max_bytes: MAX_MEDIA_BYTES,
            size_bytes: byteLength,
          },
          413,
          request
        );
      }
      const existing = await getFileMeta(env, path);
      const result = await putBinaryFile(env, {
        path,
        contentBase64: body.content_base64.replace(/\s/g, ""),
        message: body.message || `studio: upload ${path}`,
        sha: existing?.sha || null,
      });
      return json(
        {
          ok: true,
          path,
          public_path: publicMediaPath(path),
          commit: result.commit?.sha || null,
          size_bytes: byteLength,
        },
        200,
        request
      );
    }

    if (head === "search" && parts[1] === "xcite" && request.method === "GET") {
      const q = String(new URL(request.url).searchParams.get("q") || "")
        .trim()
        .toLowerCase();
      const indexPath = "content/collections"; // search filenames + keys via tree peeks
      const results = await searchKeys(env, q, ["articles", "posts", "products", "projects"]);
      return json({ results }, 200, request);
    }

    if (head === "search" && parts[1] === "cite" && request.method === "GET") {
      const q = String(new URL(request.url).searchParams.get("q") || "")
        .trim()
        .toLowerCase();
      const entries = await listDir(env, "content/collections/bibliography");
      const results = entries
        .map((e) => e.name.replace(/\.ya?ml$/i, ""))
        .filter((k) => !q || k.toLowerCase().includes(q))
        .slice(0, 30)
        .map((key) => ({ key, label: key }));
      return json({ results }, 200, request);
    }

    if (head === "schema" && request.method === "GET") {
      const file = await getFile(env, "studio/schema.yml");
      if (!file) return json({ error: "schema_missing" }, 404, request);
      return json({ yaml: file.content }, 200, request);
    }

    // AC-PRF-01…17 — Correct / Refine (docs/features/studio-proof.md).
    if (head === "rewrite" && request.method === "POST") {
      const rewriteBudget = rewriteRateLimit(request, auth.userId);
      if (!rewriteBudget.allowed) {
        return json(
          {
            error: "rate_limited",
            message: "AI Proof is limited to a few runs a minute. Wait, then try again.",
          },
          429,
          request,
          { "Retry-After": String(rewriteBudget.retryAfterSec) }
        );
      }
      let body;
      try {
        body = await request.json();
      } catch {
        return json({ error: "invalid_body" }, 400, request);
      }
      try {
        const result = await runRewrite(env, body);
        return json(result, 200, request);
      } catch (err) {
        const code = err.code || "server_error";
        const status = err.status || 500;
        return json({ error: code, message: String(err.message || err) }, status, request);
      }
    }

    void listSchemaCollections;
    return json({ error: "not_found", path: parts }, 404, request);
  } catch (err) {
    const status = err.status || 500;
    const body = {
      error: err.code || "server_error",
      message: String(err.message || err),
    };
    if (err.detail) body.detail = String(err.detail).slice(0, 400);
    return json(body, status, request);
  }
}

function splitFrontMatter(raw) {
  const text = String(raw || "");
  if (!text.startsWith("---")) {
    return { frontMatter: {}, body: text, rawFm: "" };
  }
  const end = text.indexOf("\n---", 3);
  if (end < 0) return { frontMatter: {}, body: text, rawFm: "" };
  const rawFm = text.slice(4, end).trimEnd();
  const body = text.slice(end + 4).replace(/^\r?\n/, "");
  const frontMatter = {};
  for (const line of rawFm.split(/\r?\n/)) {
    const m = line.match(/^([A-Za-z0-9_]+):\s*(.*)$/);
    if (m && !m[2].startsWith("|") && !m[2].startsWith(">") && m[2] !== "") {
      let v = m[2].trim();
      if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
        v = v.slice(1, -1);
      }
      if (v === "true") v = true;
      else if (v === "false") v = false;
      frontMatter[m[1]] = v;
    }
  }
  return { frontMatter, body, rawFm };
}

/** Repo path → cite path (`content/media/images/x.png` → `/media/images/x.png`). */
function publicMediaPath(repoPath) {
  const path = String(repoPath || "");
  if (path === MEDIA_ROOT || path.startsWith(`${MEDIA_ROOT}/`)) {
    return path.replace(/^content/, "") || "/media";
  }
  return null;
}

function mediaSegmentsOk(path) {
  const rest = path.slice(MEDIA_ROOT.length).replace(/^\//, "");
  if (!rest) return true;
  return rest.split("/").every((seg) => SAFE_SEGMENT.test(seg));
}

/** Directory under content/media (inclusive of root). */
function normalizeMediaDir(raw) {
  let path = normalizeRepoPath(raw);
  if (!path) return null;
  path = path.replace(/\/+$/, "");
  if (path === MEDIA_ROOT) return MEDIA_ROOT;
  if (!path.startsWith(`${MEDIA_ROOT}/`)) return null;
  if (!mediaSegmentsOk(path)) return null;
  return path;
}

/** File path under content/media (not a bare directory root). */
function normalizeMediaFile(raw) {
  const path = normalizeRepoPath(raw);
  if (!path || !path.startsWith(`${MEDIA_ROOT}/`)) return null;
  if (path.endsWith("/")) return null;
  if (!mediaSegmentsOk(path)) return null;
  const name = path.split("/").pop();
  if (!name || name === ".gitkeep") return null;
  return path;
}

async function searchKeys(env, q, collections) {
  const results = [];
  for (const name of collections) {
    const entries = await listDir(env, `content/collections/${name}`);
    for (const entry of entries) {
      const stem = entry.name.replace(/\.(md|markdown)$/i, "");
      const keyGuess = stem.includes("-") ? stem.replace(/^\d{4}-\d{2}-\d{2}-/, "") : stem;
      if (q && !keyGuess.toLowerCase().includes(q) && !stem.toLowerCase().includes(q)) {
        continue;
      }
      results.push({ key: keyGuess, path: entry.path, collection: name, label: keyGuess });
      if (results.length >= 30) return results;
    }
  }
  return results;
}
