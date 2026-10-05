import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import {
  buildAuthSessionReturnUrl,
  buildWebViewNavigateScript,
  isGoogleOAuthUrl,
} from './oauth-external-browser';

describe('isGoogleOAuthUrl', () => {
  it('detects accounts.google.com and oauth2.googleapis.com', () => {
    assert.equal(
      isGoogleOAuthUrl(
        'https://accounts.google.com/o/oauth2/v2/auth?client_id=abc&redirect_uri=https%3A%2F%2Fclerk.example',
      ),
      true,
    );
    assert.equal(isGoogleOAuthUrl('https://oauth2.googleapis.com/token'), true);
  });

  it('detects www.google.com sign-in paths only', () => {
    assert.equal(isGoogleOAuthUrl('https://www.google.com/signin/oauth/legacy'), true);
    assert.equal(isGoogleOAuthUrl('https://www.google.com/search?q=studio'), false);
  });

  it('leaves Studio, Clerk, and garbage URLs inside the WebView', () => {
    assert.equal(isGoogleOAuthUrl('https://example.com/studio/'), false);
    assert.equal(isGoogleOAuthUrl('https://clerk.example.com/v1/oauth'), false);
    assert.equal(isGoogleOAuthUrl('not-a-url'), false);
  });
});

describe('buildAuthSessionReturnUrl', () => {
  it('uses the Studio path as the return prefix', () => {
    assert.equal(
      buildAuthSessionReturnUrl('https://example.com/studio'),
      'https://example.com/studio/',
    );
    assert.equal(
      buildAuthSessionReturnUrl('https://example.com/studio/'),
      'https://example.com/studio/',
    );
  });
});

describe('buildWebViewNavigateScript', () => {
  it('replaces the WebView location with the OAuth callback URL', () => {
    const target = 'https://example.com/studio/?__clerk_status=complete';
    assert.equal(
      buildWebViewNavigateScript(target),
      `window.location.replace(${JSON.stringify(target)}); true;`,
    );
  });
});
