/**
 * GitHub Contents API helpers. PAT stays server-side (AC-STU-09).
 */

function repoParts(env) {
  const full = String(env.GITHUB_REPO || "").trim();
  if (!full) throw new Error("GITHUB_REPO is required (owner/name)");
  const [owner, repo] = full.split("/");
  if (!owner || !repo) throw new Error("GITHUB_REPO must be owner/name");
  return { owner, repo };
}

/**
 * GitHub Contents failures used to surface as `{ error: "server_error" }` with
 * the status buried after a colon. A phone toolbar ellipsizes that to
 * "server_err…", so the code and the sentence have to travel separately.
 *
 * Primary and secondary rate limits are 403 or 429. A bare 403 is also how
 * GitHub reports a bad token, so only a rate-limit sentence counts.
 */
export function isGithubRateLimit(status, body) {
  if (status === 429) return true;
  if (status !== 403) return false;
  const lower = String(body || "").toLowerCase();
  return (
    lower.includes("rate limit") ||
    lower.includes("secondary rate") ||
    lower.includes("abuse detection")
  );
}

/**
 * @param {string} op
 * @param {number} status
 * @param {string} text
 * @returns {{ message: string, code: string, status: number }}
 */
export function classifyGithubFailure(op, status, text) {
  const conflict = status === 409;
  if (conflict) {
    return {
      message:
        "This file changed on GitHub since Studio opened it. Reload it, then save again.",
      code: "conflict",
      status,
    };
  }
  if (isGithubRateLimit(status, text)) {
    return {
      message: "GitHub is rate-limiting Studio. Wait a minute, then save again.",
      code: "github_rate_limited",
      status: 429,
    };
  }
  return {
    message: `GitHub ${op} failed (${status}).`,
    code: "github_error",
    status: status >= 400 && status < 600 ? status : 502,
  };
}

function githubFail(op, res, text) {
  const classified = classifyGithubFailure(op, res.status, text);
  const err = new Error(classified.message);
  err.status = classified.status;
  err.code = classified.code;
  err.detail = String(text || "").slice(0, 400);
  return err;
}

async function gh(env, path, init = {}) {
  const token = env.GITHUB_TOKEN;
  if (!token) {
    const err = new Error("GITHUB_TOKEN not configured");
    err.status = 503;
    err.code = "github_unconfigured";
    throw err;
  }
  const { owner, repo } = repoParts(env);
  const url = `https://api.github.com/repos/${owner}/${repo}${path}`;
  const res = await fetch(url, {
    ...init,
    headers: {
      Accept: "application/vnd.github+json",
      Authorization: `Bearer ${token}`,
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "website-studio",
      ...(init.headers || {}),
    },
  });
  return res;
}

export async function getFile(env, path) {
  const res = await gh(env, `/contents/${path}?ref=main`);
  if (res.status === 404) return null;
  if (!res.ok) {
    throw githubFail("get", res, await res.text());
  }
  const json = await res.json();
  if (json.type !== "file" || !json.content) {
    const err = new Error("not a file");
    err.status = 400;
    err.code = "not_a_file";
    throw err;
  }
  const content = new TextDecoder("utf-8").decode(
    Uint8Array.from(atob(String(json.content).replace(/\n/g, "")), (c) =>
      c.charCodeAt(0)
    )
  );
  return { path, content, sha: json.sha, size: json.size };
}

export async function putFile(env, { path, content, message, sha }) {
  const body = {
    message: message || `studio: update ${path}`,
    content: btoa(unescape(encodeURIComponent(content))),
    branch: "main",
  };
  if (sha) body.sha = sha;
  const res = await gh(env, `/contents/${path}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    throw githubFail("put", res, await res.text());
  }
  return res.json();
}

/** Delete a file. GitHub Contents DELETE requires the current blob sha. */
export async function deleteFile(env, { path, message, sha }) {
  if (!sha) {
    const err = new Error("sha required to delete");
    err.status = 400;
    err.code = "sha_required";
    throw err;
  }
  const res = await gh(env, `/contents/${path}`, {
    method: "DELETE",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      message: message || `studio: delete ${path}`,
      sha,
      branch: "main",
    }),
  });
  if (!res.ok) {
    throw githubFail("delete", res, await res.text());
  }
  return res.json();
}

/**
 * Put a binary file. `contentBase64` is already base64 of raw bytes
 * (GitHub Contents API create/update limit: 100 MB; Studio caps lower).
 */
export async function putBinaryFile(env, { path, contentBase64, message, sha }) {
  const body = {
    message: message || `studio: upload ${path}`,
    content: contentBase64,
    branch: "main",
  };
  if (sha) body.sha = sha;
  const res = await gh(env, `/contents/${path}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    throw githubFail("put", res, await res.text());
  }
  return res.json();
}

/** Metadata only — safe for binary paths (no UTF-8 decode). */
export async function getFileMeta(env, path) {
  const res = await gh(env, `/contents/${path}?ref=main`);
  if (res.status === 404) return null;
  if (!res.ok) {
    throw githubFail("get", res, await res.text());
  }
  const json = await res.json();
  return {
    path,
    sha: json.sha || null,
    size: json.size || 0,
    type: json.type || null,
  };
}

/** List directory entries (files and dirs). */
export async function listEntries(env, dirPath) {
  const res = await gh(env, `/contents/${dirPath}?ref=main`);
  if (res.status === 404) return [];
  if (!res.ok) {
    throw githubFail("list", res, await res.text());
  }
  const json = await res.json();
  if (!Array.isArray(json)) return [];
  return json
    .filter((e) => e.type === "file" || e.type === "dir")
    .map((e) => ({
      name: e.name,
      path: e.path,
      sha: e.sha,
      size: e.size || 0,
      type: e.type === "dir" ? "dir" : "file",
    }));
}

export async function listDir(env, dirPath) {
  const entries = await listEntries(env, dirPath);
  return entries.filter((e) => e.type === "file");
}

/** Very small front-matter peek for tree listings (title/date/thumbnail + list meta). */
export function peekMeta(raw) {
  const empty = {
    title: null,
    date: null,
    start_date: null,
    end_date: null,
    start: null,
    end: null,
    thumbnail: null,
    key: null,
    published: null,
    language: null,
    category: null,
    type: null,
    company: null,
    status: null,
    engagement: null,
    tags: null,
  };
  const text = String(raw || "");
  if (!text.startsWith("---")) return empty;
  const fmEnd = text.indexOf("\n---", 3);
  if (fmEnd < 0) return empty;
  const fm = text.slice(3, fmEnd + 1);
  const grab = (name) => {
    const re = new RegExp(`^${name}:\\s*(.+)$`, "m");
    const m = fm.match(re);
    if (!m) return null;
    let v = m[1].trim();
    if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) {
      v = v.slice(1, -1);
    }
    return v;
  };
  /** Full tag list from inline `[a, b]` or a YAML block list. */
  const grabTags = () => {
    const clean = (s) => String(s || "").trim().replace(/^["']|["']$/g, "");
    const inline = fm.match(/^tags:\s*\[([^\]]*)\]/m);
    if (inline) {
      const tags = inline[1]
        .split(",")
        .map(clean)
        .filter(Boolean);
      return tags.length ? tags : null;
    }
    const block = fm.match(/^tags:\s*\n((?:[ \t]*-[ \t]*.+\n?)+)/m);
    if (block) {
      const tags = block[1]
        .split("\n")
        .map((line) => {
          const m = line.match(/^[ \t]*-[ \t]*(.+)$/);
          return m ? clean(m[1]) : "";
        })
        .filter(Boolean);
      return tags.length ? tags : null;
    }
    return null;
  };
  const startDate = grab("start_date");
  const endDate = grab("end_date");
  const start = grab("start");
  const end = grab("end");
  return {
    title: grab("title") || grab("product") || grab("project") || grab("name") || grab("position"),
    // Collapsed start for sort; list meta uses start_date/end_date or start/end.
    date: grab("date") || startDate || start,
    start_date: startDate,
    end_date: endDate,
    start,
    end,
    thumbnail: grab("thumbnail"),
    key: grab("key"),
    published: grab("published"),
    language: grab("language"),
    category: grab("category"),
    type: grab("type"),
    company: grab("company"),
    status: grab("status"),
    engagement: grab("engagement"),
    tags: grabTags(),
  };
}
