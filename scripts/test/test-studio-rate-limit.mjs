#!/usr/bin/env node
/**
 * Studio save must not share a request budget with reads.
 * Spec: docs/features/studio.md §4 (mutating-route throttle).
 */
import assert from "node:assert/strict";
import {
  classifyGithubFailure,
  isGithubRateLimit,
} from "../../functions/api/studio/_lib/github.js";
import {
  isMutatingMethod,
  takeToken,
} from "../../functions/api/studio/_lib/rate-limit.js";

const windowMs = 60_000;
const max = 3;
const now = 1_700_000_000_000;

{
  const store = new Map();
  for (let i = 0; i < max; i += 1) {
    const decision = takeToken(store, "user:1.2.3.4", now, { windowMs, max });
    assert.equal(decision.allowed, true, `write ${i + 1} should be allowed`);
  }
  const blocked = takeToken(store, "user:1.2.3.4", now, { windowMs, max });
  assert.equal(blocked.allowed, false);
  assert.ok(blocked.retryAfterSec >= 1 && blocked.retryAfterSec <= 60);

  const otherUser = takeToken(store, "other:1.2.3.4", now, { windowMs, max });
  assert.equal(otherUser.allowed, true, "a different key has its own budget");

  const reset = takeToken(store, "user:1.2.3.4", now + windowMs, { windowMs, max });
  assert.equal(reset.allowed, true, "the window resets on the boundary");
}

{
  assert.equal(isMutatingMethod("PUT"), true);
  assert.equal(isMutatingMethod("POST"), true);
  assert.equal(isMutatingMethod("GET"), false);
  assert.equal(isMutatingMethod("OPTIONS"), false);
}

{
  assert.equal(isGithubRateLimit(429, ""), true);
  assert.equal(
    isGithubRateLimit(403, "You have exceeded a secondary rate limit."),
    true
  );
  assert.equal(isGithubRateLimit(403, "Resource not accessible by integration"), false);
  assert.equal(isGithubRateLimit(404, "Not Found"), false);

  const limited = classifyGithubFailure(
    "put",
    403,
    '{"message":"You have exceeded a secondary rate limit."}'
  );
  assert.equal(limited.code, "github_rate_limited");
  assert.equal(limited.status, 429);
  assert.match(limited.message, /Wait a minute/);

  const conflict = classifyGithubFailure("put", 409, "sha mismatch");
  assert.equal(conflict.code, "conflict");

  const missing = classifyGithubFailure("get", 404, "Not Found");
  assert.equal(missing.code, "github_error");
  assert.match(missing.message, /GitHub get failed \(404\)/);
}

console.log("All Studio rate-limit checks passed.");
