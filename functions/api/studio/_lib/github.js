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

/**
 * Map a GitHub Actions workflow run to Studio pipeline UI state.
 * @param {{ status?: string, conclusion?: string|null }|null} run
 * @returns {"awaiting_run"|"running"|"ok"|"error"|"idle"}
 */
export function mapWorkflowRunState(run) {
  if (!run) return "idle";
  const status = String(run.status || "");
  if (status === "completed") {
    return run.conclusion === "success" ? "ok" : "error";
  }
  return "running";
}

/**
 * Read pandorga.content.workflow(+ workflow_ref) from site `_config.yml`.
 * Tiny indent-aware peek — no YAML dependency in the Function.
 */
export function parseContentWorkflowFromConfig(yamlText) {
  const lines = String(yamlText || "").split(/\r?\n/);
  let inPandorga = false;
  let pandorgaIndent = 0;
  let inContent = false;
  let contentIndent = 0;
  let workflow = null;
  let workflowRef = null;

  for (const line of lines) {
    if (!line.trim() || /^\s*#/.test(line)) continue;
    const m = line.match(/^(\s*)([A-Za-z0-9_]+):\s*(.*?)\s*$/);
    if (!m) continue;
    const indent = m[1].length;
    const key = m[2];
    let val = m[3];
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }

    if (!inPandorga) {
      if (key === "pandorga" && indent === 0) {
        inPandorga = true;
        pandorgaIndent = indent;
      }
      continue;
    }

    if (indent <= pandorgaIndent && key !== "pandorga") break;

    if (key === "content" && indent > pandorgaIndent) {
      inContent = true;
      contentIndent = indent;
      continue;
    }

    if (inContent) {
      if (indent <= contentIndent) {
        inContent = false;
        if (key === "content" && indent > pandorgaIndent) {
          inContent = true;
          contentIndent = indent;
        }
        continue;
      }
      if (key === "workflow" && val) workflow = val;
      if (key === "workflow_ref" && val) workflowRef = val;
    }
  }

  return { workflow, workflowRef };
}

/**
 * Workflow file + branch: optional env override, else `_config.yml`
 * (`pandorga.content.workflow`).
 */
export async function resolveContentWorkflowConfig(env) {
  const envWorkflow = String(env.STUDIO_CONTENT_WORKFLOW || "").trim();
  const envRef = String(env.STUDIO_CONTENT_WORKFLOW_REF || "").trim();
  if (envWorkflow) {
    return {
      workflow: envWorkflow,
      ref: envRef || "main",
      source: "env",
    };
  }

  try {
    const file = await getFile(env, "_config.yml");
    if (file?.content) {
      const parsed = parseContentWorkflowFromConfig(file.content);
      if (parsed.workflow) {
        return {
          workflow: parsed.workflow,
          ref: parsed.workflowRef || envRef || "main",
          source: "config",
        };
      }
    }
  } catch {
    /* fall through to unconfigured */
  }

  return { workflow: null, ref: envRef || "main", source: null };
}

/**
 * Look up the content-pipeline workflow run for a commit SHA, or the latest
 * run on the branch when `sha` is omitted.
 * Requires the PAT to have Actions read (fine-grained: Actions → Read).
 *
 * @param {object} env
 * @param {string} [sha]
 */
export async function getContentPipelineStatus(env, sha) {
  const resolved = await resolveContentWorkflowConfig(env);
  const workflowFile = resolved.workflow;
  const ref = resolved.ref || "main";
  const commitSha = String(sha || "").trim().toLowerCase();

  if (!workflowFile) {
    return {
      mode: "production",
      workflow: null,
      sha: commitSha,
      state: "unconfigured",
      run: null,
      error: null,
      source: null,
    };
  }
  if (commitSha && !/^[0-9a-f]{7,40}$/.test(commitSha)) {
    const err = new Error("sha must be 7–40 hex chars when provided");
    err.status = 400;
    err.code = "invalid_sha";
    throw err;
  }

  const wfRes = await gh(
    env,
    `/actions/workflows/${encodeURIComponent(workflowFile)}`
  );
  if (wfRes.status === 404) {
    return {
      mode: "production",
      workflow: workflowFile,
      sha: commitSha,
      state: "unconfigured",
      run: null,
      error: "workflow_not_found",
      source: resolved.source,
    };
  }
  if (wfRes.status === 401 || wfRes.status === 403) {
    const text = await wfRes.text();
    if (wfRes.status === 403 && isGithubRateLimit(403, text)) {
      throw githubFail("actions", wfRes, text);
    }
    const err = new Error(
      "GitHub token cannot read Actions. Grant Actions: Read on the fine-grained PAT."
    );
    err.status = 403;
    err.code = "actions_forbidden";
    err.detail = String(text || "").slice(0, 400);
    throw err;
  }
  if (!wfRes.ok) {
    throw githubFail("actions", wfRes, await wfRes.text());
  }

  const workflow = await wfRes.json();
  let runsPath =
    `/actions/workflows/${workflow.id}/runs` +
    `?branch=${encodeURIComponent(ref)}` +
    `&per_page=5`;
  if (commitSha) {
    runsPath += `&head_sha=${encodeURIComponent(commitSha)}`;
  }
  const runsRes = await gh(env, runsPath);
  if (runsRes.status === 401 || runsRes.status === 403) {
    const text = await runsRes.text();
    if (runsRes.status === 403 && isGithubRateLimit(403, text)) {
      throw githubFail("actions", runsRes, text);
    }
    const err = new Error(
      "GitHub token cannot read Actions. Grant Actions: Read on the fine-grained PAT."
    );
    err.status = 403;
    err.code = "actions_forbidden";
    err.detail = String(text || "").slice(0, 400);
    throw err;
  }
  if (!runsRes.ok) {
    throw githubFail("actions", runsRes, await runsRes.text());
  }

  const payload = await runsRes.json();
  const runs = Array.isArray(payload.workflow_runs) ? payload.workflow_runs : [];
  const run = runs[0] || null;
  let state = mapWorkflowRunState(run);
  // Watching a specific SHA with no run yet → waiting for the push trigger.
  if (commitSha && !run) state = "awaiting_run";

  return {
    mode: "production",
    workflow: workflowFile,
    sha: commitSha || (run?.head_sha ? String(run.head_sha).toLowerCase() : ""),
    state,
    run: run
      ? {
          id: run.id,
          status: run.status || null,
          conclusion: run.conclusion || null,
          html_url: run.html_url || null,
          updated_at: run.updated_at || null,
        }
      : null,
    error: null,
    source: resolved.source,
  };
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
