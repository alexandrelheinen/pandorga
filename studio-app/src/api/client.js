let getToken = async () => null;

export function setTokenGetter(fn) {
  getToken = fn;
}

async function api(path, init = {}) {
  const token = await getToken();
  const headers = {
    Accept: "application/json",
    ...(init.headers || {}),
  };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (init.body && !headers["Content-Type"]) {
    headers["Content-Type"] = "application/json";
  }
  const res = await fetch(`/api/studio/${path.replace(/^\//, "")}`, {
    ...init,
    headers,
  });
  const text = await res.text();
  let data = null;
  try {
    data = text ? JSON.parse(text) : null;
  } catch {
    data = { raw: text };
  }
  if (!res.ok) {
    // Prefer the sentence. Joining the code in front (`server_error: …`) is
    // what a narrow toolbar ellipsizes down to the code alone.
    const message = String(data?.message || data?.error || `HTTP ${res.status}`);
    const err = new Error(message);
    err.status = res.status;
    err.code = data?.error || "";
    err.data = data;
    throw err;
  }
  return data;
}

export const studioApi = {
  session: () => api("session"),
  tree: (collectionPath) =>
    api(`tree?path=${encodeURIComponent(collectionPath)}`),
  getFile: (path) => api(`file?path=${encodeURIComponent(path)}`),
  putFile: ({ path, content, message, sha }) =>
    api("file", {
      method: "PUT",
      body: JSON.stringify({ path, content, message, sha }),
    }),
  deleteFile: ({ path, message, sha }) =>
    api("file", {
      method: "DELETE",
      body: JSON.stringify({ path, message, sha }),
    }),
  listMedia: (dirPath) =>
    api(`media?path=${encodeURIComponent(dirPath || "content/media")}`),
  uploadMedia: ({ path, content_base64, message }) =>
    api("media", {
      method: "POST",
      body: JSON.stringify({ path, content_base64, message }),
    }),
  createMediaFolder: ({ path, message }) =>
    api("media/folder", {
      method: "POST",
      body: JSON.stringify({ path, message }),
    }),
  searchXcite: (q) => api(`search/xcite?q=${encodeURIComponent(q || "")}`),
  searchCite: (q) => api(`search/cite?q=${encodeURIComponent(q || "")}`),
  /** Correct / Refine — docs/features/studio-proof.md (AC-PRF-01). */
  rewrite: (payload) =>
    api("rewrite", {
      method: "POST",
      body: JSON.stringify(payload),
    }),
  /** Content-pipeline run for a commit SHA (production). */
  pipelineStatus: (sha, workflow = null) => {
    const params = new URLSearchParams({ sha: String(sha || "") });
    if (workflow) params.set("workflow", String(workflow));
    return api(`pipeline-status?${params.toString()}`);
  },
};
