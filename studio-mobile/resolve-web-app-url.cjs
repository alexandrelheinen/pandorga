const DEFAULT_WEB_APP_URL = 'https://example.com/studio/';
const PLACEHOLDER_VALUES = new Set(['undefined', 'null']);

function isPlaceholder(value) {
  return PLACEHOLDER_VALUES.has(value.trim().toLowerCase());
}

/** @param {string} value */
function normalizeStudioUrl(value) {
  let parsed;
  try {
    parsed = new URL(value.trim());
  } catch {
    return null;
  }

  if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') return null;
  if (!parsed.hostname || isPlaceholder(parsed.hostname)) return null;

  let path = parsed.pathname || '/';
  if (path === '/studio') path = '/studio/';
  if (!path.startsWith('/studio/')) return null;
  if (!path.endsWith('/')) path += '/';

  return `${parsed.origin}${path}${parsed.search}`;
}

/** @param {string | undefined | null} value */
function isUsableWebAppUrl(value) {
  return typeof value === 'string' && !isPlaceholder(value) && normalizeStudioUrl(value) !== null;
}

/**
 * First usable candidate, or the default Studio URL (tests / unset env).
 * Production apps must set STUDIO_WEB_APP_URL via EAS.
 * @param {...(string | undefined | null)} candidates
 */
function resolveWebAppUrl(...candidates) {
  for (const candidate of candidates) {
    if (typeof candidate !== 'string') continue;
    const trimmed = candidate.trim();
    if (!trimmed || isPlaceholder(trimmed)) continue;
    const normalized = normalizeStudioUrl(trimmed);
    if (normalized) return normalized;
  }
  return DEFAULT_WEB_APP_URL;
}

/**
 * Resolve the shell start URL for a given EAS profile.
 * Release builds prefer `STUDIO_WEB_APP_URL` from EAS `env` (or the local
 * environment). When unset or unusable, fall back to example.com.
 * @param {string | undefined | null} profile
 * @param {string | undefined | null} envUrl
 */
function resolveConfiguredWebAppUrl(profile, envUrl) {
  void profile;
  return resolveWebAppUrl(envUrl);
}

module.exports = {
  DEFAULT_WEB_APP_URL,
  resolveWebAppUrl,
  resolveConfiguredWebAppUrl,
};
