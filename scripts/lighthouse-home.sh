#!/usr/bin/env bash
# One Lighthouse mobile run against the built example home.
# Thresholds apply to releases. LIGHTHOUSE_MODE=enforce fails below 75
# and warns below 90. LIGHTHOUSE_MODE=warn never fails the run. PLT-AC-24.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SITE="${ROOT}/examples/minimal/_site"
PORT="${LIGHTHOUSE_PORT:-4173}"
OUT="${LIGHTHOUSE_REPORT:-/tmp/lighthouse-home.json}"
FAIL_BELOW=75
WARN_BELOW=90
MODE="${LIGHTHOUSE_MODE:-enforce}"

fail() {
  echo "ERROR: $1" >&2
  exit 1
}

step() { echo "==> $1"; }

if [[ "${MODE}" != "enforce" && "${MODE}" != "warn" ]]; then
  fail "LIGHTHOUSE_MODE must be enforce or warn (got ${MODE})"
fi

[[ -f "${SITE}/index.html" ]] || fail "missing ${SITE}/index.html (run scripts/validate.sh first)"

if [[ -n "${CHROME_PATH:-}" && -x "${CHROME_PATH}" ]]; then
  CHROME="${CHROME_PATH}"
elif command -v google-chrome >/dev/null 2>&1; then
  CHROME="$(command -v google-chrome)"
elif command -v google-chrome-stable >/dev/null 2>&1; then
  CHROME="$(command -v google-chrome-stable)"
else
  fail "Chrome is not installed"
fi

step "Serving ${SITE} (gzip, concurrent)"
python3 "${ROOT}/scripts/lighthouse_server.py" "${PORT}" "${SITE}" >/tmp/lighthouse-home-server.log 2>&1 &
SERVER_PID=$!
cleanup() {
  kill "${SERVER_PID}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

ready=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  if curl -sf "http://127.0.0.1:${PORT}/" >/dev/null; then
    ready=1
    break
  fi
  sleep 0.25
done
[[ "${ready}" == "1" ]] || fail "example server did not answer on port ${PORT}"

step "Lighthouse mobile (one run)"
rm -f "${OUT}"
npx --yes lighthouse@13.5.0 "http://127.0.0.1:${PORT}/" \
  --only-categories=performance \
  --form-factor=mobile \
  --output=json \
  --output-path="${OUT}" \
  --quiet \
  --no-enable-error-reporting \
  --chrome-path="${CHROME}" \
  --chrome-flags="--headless=new --no-sandbox --disable-gpu"

python3 - "${OUT}" "${FAIL_BELOW}" "${WARN_BELOW}" "${MODE}" <<'PY'
import json
import sys

path, fail_below, warn_below, mode = sys.argv[1:]
fail_below = int(fail_below)
warn_below = int(warn_below)
report = json.load(open(path, encoding="utf-8"))
raw = report.get("categories", {}).get("performance", {}).get("score")
if raw is None:
    print("ERROR: Lighthouse returned no performance score", file=sys.stderr)
    sys.exit(1)
score = int(round(float(raw) * 100))
print(f"Lighthouse mobile performance: {score} ({mode})")
campaign = (
    "A score from 75 to 89 is acceptable only to ship a bug fix. "
    "An urgent performance campaign must bring it back to 90 or above."
)
if score < fail_below and mode == "enforce":
    print(f"::error::Lighthouse mobile performance {score} is below {fail_below}")
    sys.exit(1)
if score < fail_below:
    print(
        f"::warning::Lighthouse mobile performance {score} is below {fail_below}. "
        "Thresholds apply to releases. This run only warns."
    )
if score < warn_below:
    print(
        f"::warning::Lighthouse mobile performance {score} is below {warn_below}. "
        + campaign
    )
PY
