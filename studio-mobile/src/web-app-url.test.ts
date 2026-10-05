import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { afterEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { DEFAULT_WEB_APP_URL, readWebAppUrl, resolveWebAppUrl } from './web-app-url';
import Constants from './test-fixtures/expo-constants';

const require = createRequire(import.meta.url);
const { resolveConfiguredWebAppUrl } = require('../resolve-web-app-url.cjs') as {
  resolveConfiguredWebAppUrl: (profile: string | undefined, envUrl: string | undefined) => string;
};

const mobileRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const FRESHY_EAS_PROJECT_ID = 'ff3b74f8-863b-41cd-a83a-1c9f37a1dd42';
const WEBSITE_EAS_PROJECT_ID = '711afc3e-1152-4c56-82e5-e6a9606e5761';

describe('resolveWebAppUrl', () => {
  it('falls back to example.com Studio when the value is missing or empty', () => {
    assert.equal(resolveWebAppUrl(undefined), DEFAULT_WEB_APP_URL);
    assert.equal(resolveWebAppUrl(null), DEFAULT_WEB_APP_URL);
    assert.equal(resolveWebAppUrl(''), DEFAULT_WEB_APP_URL);
    assert.equal(DEFAULT_WEB_APP_URL, 'https://example.com/studio/');
  });

  it('rejects the site root and other paths that are not /studio/', () => {
    assert.equal(resolveWebAppUrl('https://example.com'), DEFAULT_WEB_APP_URL);
    assert.equal(resolveWebAppUrl('https://example.com/'), DEFAULT_WEB_APP_URL);
    assert.equal(resolveWebAppUrl('https://example.com/pages/cv/'), DEFAULT_WEB_APP_URL);
  });

  it('keeps a trailing slash on /studio/', () => {
    assert.equal(
      resolveWebAppUrl('http://127.0.0.1:4000/studio'),
      'http://127.0.0.1:4000/studio/',
    );
    assert.equal(
      resolveWebAppUrl('http://127.0.0.1:4000/studio/'),
      'http://127.0.0.1:4000/studio/',
    );
  });

  it('rejects placeholders and non-http values', () => {
    assert.equal(resolveWebAppUrl('undefined'), DEFAULT_WEB_APP_URL);
    assert.equal(resolveWebAppUrl('https://undefined/studio/'), DEFAULT_WEB_APP_URL);
    assert.equal(resolveWebAppUrl('not a url'), DEFAULT_WEB_APP_URL);
    assert.equal(resolveWebAppUrl('ftp://example.com/studio/'), DEFAULT_WEB_APP_URL);
  });
});

describe('resolveConfiguredWebAppUrl', () => {
  it('uses STUDIO_WEB_APP_URL on the release profile when set', () => {
    assert.equal(
      resolveConfiguredWebAppUrl('release', 'https://example.com/studio/'),
      'https://example.com/studio/',
    );
    assert.equal(
      resolveConfiguredWebAppUrl('release', 'https://studio.example.org/studio'),
      'https://studio.example.org/studio/',
    );
  });

  it('falls back to example.com on release when env is unset', () => {
    assert.equal(resolveConfiguredWebAppUrl('release', undefined), DEFAULT_WEB_APP_URL);
    assert.equal(resolveConfiguredWebAppUrl('release', ''), DEFAULT_WEB_APP_URL);
  });

  it('uses STUDIO_WEB_APP_URL for local expo start', () => {
    assert.equal(
      resolveConfiguredWebAppUrl(undefined, 'http://127.0.0.1:4000/studio'),
      'http://127.0.0.1:4000/studio/',
    );
  });
});

describe('readWebAppUrl', () => {
  const originalEnv = process.env.STUDIO_WEB_APP_URL;

  afterEach(() => {
    Constants.expoConfig = undefined;
    Constants.manifest = undefined;
    Constants.manifest2 = undefined;
    if (originalEnv === undefined) {
      delete process.env.STUDIO_WEB_APP_URL;
    } else {
      process.env.STUDIO_WEB_APP_URL = originalEnv;
    }
  });

  it('falls back to example.com when Expo extra is missing', () => {
    delete process.env.STUDIO_WEB_APP_URL;
    assert.equal(readWebAppUrl(), DEFAULT_WEB_APP_URL);
  });

  it('reads a valid extra URL and keeps /studio/', () => {
    Constants.expoConfig = { extra: { webAppUrl: 'http://127.0.0.1:4000/studio' } };
    assert.equal(readWebAppUrl(), 'http://127.0.0.1:4000/studio/');
  });
});

describe('release contract', () => {
  it('keeps generic identity defaults and EAS release env', () => {
    const eas = JSON.parse(readFileSync(join(mobileRoot, 'eas.json'), 'utf8')) as {
      cli: { appVersionSource: string };
      build: {
        release: {
          autoIncrement: boolean;
          android: { buildType: string };
          env: { STUDIO_WEB_APP_URL: string };
        };
      };
    };
    const appConfig = readFileSync(join(mobileRoot, 'app.config.ts'), 'utf8');
    const envExample = readFileSync(join(mobileRoot, '.env.example'), 'utf8');

    assert.equal(eas.cli.appVersionSource, 'remote');
    assert.equal(eas.build.release.autoIncrement, true);
    assert.equal(eas.build.release.android.buildType, 'apk');
    assert.equal(eas.build.release.env.STUDIO_WEB_APP_URL, DEFAULT_WEB_APP_URL);
    assert.match(appConfig, /com\.example\.pandorga\.studio/);
    assert.match(appConfig, /STUDIO_ANDROID_PACKAGE/);
    assert.match(appConfig, /ANDROID_PACKAGE/);
    assert.match(appConfig, /STUDIO_APP_NAME/);
    assert.match(appConfig, /REPLACE_WITH_EAS_PROJECT_ID/);
    assert.match(appConfig, /softwareKeyboardLayoutMode:\s*'resize'/);
    assert.doesNotMatch(appConfig, new RegExp(FRESHY_EAS_PROJECT_ID));
    assert.doesNotMatch(appConfig, new RegExp(WEBSITE_EAS_PROJECT_ID));
    assert.match(envExample, /STUDIO_WEB_APP_URL=/);
    assert.match(envExample, /EAS_PROJECT_ID=/);
    assert.match(envExample, /STUDIO_ANDROID_PACKAGE=/);
    assert.match(envExample, /STUDIO_APP_NAME=/);
  });

  it('ships a 1024px hexagon icon, adaptive icon, and splash', () => {
    for (const name of ['icon.png', 'adaptive-icon.png', 'splash.png']) {
      const bytes = readFileSync(join(mobileRoot, 'assets', name));
      assert.equal(bytes.subarray(1, 4).toString('ascii'), 'PNG');
      assert.equal(bytes.readUInt32BE(16), 1024);
      assert.equal(bytes.readUInt32BE(20), 1024);
    }
  });
});
