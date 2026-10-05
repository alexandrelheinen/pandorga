/** Hostnames Google uses for OAuth sign-in (blocked inside WebViews). */
const GOOGLE_OAUTH_HOSTS = new Set(['accounts.google.com', 'oauth2.googleapis.com']);

/**
 * Returns true when the URL loads Google's OAuth UI, which must open in the
 * system browser (Chrome Custom Tabs) instead of a WebView.
 */
export function isGoogleOAuthUrl(url: string): boolean {
  try {
    const parsed = new URL(url);
    if (GOOGLE_OAUTH_HOSTS.has(parsed.hostname)) {
      return true;
    }
    if (parsed.hostname === 'www.google.com' && parsed.pathname.startsWith('/signin')) {
      return true;
    }
    return false;
  } catch {
    return false;
  }
}

/** Prefix watched by openAuthSessionAsync to close the browser after OAuth. */
export function buildAuthSessionReturnUrl(webAppUrl: string): string {
  const trimmed = webAppUrl.trim().replace(/\/$/, '');
  return `${trimmed}/`;
}

/** Navigate the embedded WebView after OAuth completes in the system browser. */
export function buildWebViewNavigateScript(targetUrl: string): string {
  return `window.location.replace(${JSON.stringify(targetUrl)}); true;`;
}
