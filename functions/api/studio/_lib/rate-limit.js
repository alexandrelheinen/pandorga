/**
 * Fixed-window request budget for Studio mutating routes.
 * Spec: docs/features/studio.md §4 — throttle writes, not reads.
 */

/**
 * @param {Map<string, {start: number, count: number}>} store
 * @param {string} key
 * @param {number} now
 * @param {{ windowMs: number, max: number }} limits
 * @returns {{ allowed: boolean, retryAfterSec: number }}
 */
export function takeToken(store, key, now, limits) {
  const windowMs = limits.windowMs;
  const max = limits.max;
  let bucket = store.get(key);
  if (!bucket || now < bucket.start || now - bucket.start >= windowMs) {
    bucket = { start: now, count: 0 };
    store.set(key, bucket);
  }
  bucket.count += 1;
  if (bucket.count <= max) {
    return { allowed: true, retryAfterSec: 0 };
  }
  const retryAfterSec = Math.max(
    1,
    Math.ceil((bucket.start + windowMs - now) / 1000)
  );
  return { allowed: false, retryAfterSec };
}

/** PUT/POST/PATCH/DELETE. GET (tree, file, search, session) must not spend this. */
export function isMutatingMethod(method) {
  const verb = String(method || "").toUpperCase();
  return verb === "POST" || verb === "PUT" || verb === "PATCH" || verb === "DELETE";
}

export function clientAddress(request) {
  return request.headers.get("CF-Connecting-IP") || "unknown";
}
