const { execSync } = require('node:child_process');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');

const packageJson = JSON.parse(readFileSync(join(__dirname, 'package.json'), 'utf8'));

/** Strip a single leading v: `v5.0` → `5.0`, `v5.1.2` → `5.1.2`. */
function normalizeReleaseVersion(raw) {
  return String(raw).trim().replace(/^v/i, '');
}

function readPackageVersion() {
  const version = packageJson.version;
  return typeof version === 'string' && version.trim() ? version.trim() : null;
}

function readLatestGitTag() {
  try {
    const tag = execSync('git describe --tags --abbrev=0', {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
    return tag ? normalizeReleaseVersion(tag) : null;
  } catch {
    return null;
  }
}

function readAppVersion() {
  const fromEnv = process.env.STUDIO_RELEASE_VERSION?.trim();
  if (fromEnv) return normalizeReleaseVersion(fromEnv);

  const fromPackage = readPackageVersion();
  if (fromPackage) return fromPackage;

  return readLatestGitTag() ?? '0.0.0';
}

module.exports = { readAppVersion, normalizeReleaseVersion };
