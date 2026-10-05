import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { afterEach, describe, it } from 'node:test';

const require = createRequire(import.meta.url);
const { readAppVersion } = require('./read-app-version.cjs') as {
  readAppVersion: () => string;
};

describe('readAppVersion', () => {
  const original = process.env.STUDIO_RELEASE_VERSION;

  afterEach(() => {
    if (original === undefined) {
      delete process.env.STUDIO_RELEASE_VERSION;
    } else {
      process.env.STUDIO_RELEASE_VERSION = original;
    }
  });

  it('strips one leading v from the release tag', () => {
    process.env.STUDIO_RELEASE_VERSION = 'v5.0';
    assert.equal(readAppVersion(), '5.0');
    process.env.STUDIO_RELEASE_VERSION = 'v5.1.2';
    assert.equal(readAppVersion(), '5.1.2');
  });

  it('keeps a tag that already has no v', () => {
    process.env.STUDIO_RELEASE_VERSION = '5.1.2';
    assert.equal(readAppVersion(), '5.1.2');
  });

  it('falls back to package.json when the release env var is unset', () => {
    delete process.env.STUDIO_RELEASE_VERSION;
    assert.equal(readAppVersion(), '5.0.0');
  });
});
