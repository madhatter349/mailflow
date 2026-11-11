#!/usr/bin/env bash
# The one blocking gate for this project. Run it before every push; the VPS
# verifier runs it nightly too (see /opt/vps-ci).
#
# Rules: non-zero exit = broken = no push, no deploy. No network calls.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "verify: $*" >&2; exit 1; }

echo "==> [1/5] compose file parses"
python3 - <<'PY' || fail "docker-compose.yaml is not valid YAML"
import yaml
with open("docker-compose.yaml") as f:
    yaml.safe_load(f)
PY

echo "==> [2/5] nothing publishes a host port"
if grep -nE '^\s+ports:' docker-compose.yaml >/dev/null 2>&1; then
  grep -nE '^\s+ports:' docker-compose.yaml >&2
  fail "a service publishes a port; Traefik must reach it via expose"
fi

echo "==> [3/5] no floating image tags"
if grep -nE 'image:.*:(latest|main|master)$' docker-compose.yaml >&2; then
  fail "pin an explicit image version"
fi
grep -qE 'image:.*:[0-9]+\.[0-9]+\.[0-9]+' docker-compose.yaml || fail "no semantic-versioned image found"

echo "==> [4/5] secrets are interpolated, never literals"
python3 - <<'PY' || fail "a secret looks hardcoded"
import re, sys
text = open("docker-compose.yaml").read()
bad = []
for key in ("SESSION_SECRET", "DB_PASSWORD", "ENCRYPTION_KEY"):
    for m in re.finditer(rf"^\s*{key}:\s*(\S*)\s*$", text, re.M):
        val = m.group(1)
        if not (val.startswith("${") and val.endswith("}")):
            bad.append(f"{key}={val}")
print("\n".join(bad), file=sys.stderr)
sys.exit(1 if bad else 0)
PY

echo "==> [5/5] every interpolated variable is documented"
missing=""
for var in $(grep -oE '\$\{[A-Z_]+\}' docker-compose.yaml | tr -d '${}' | sort -u); do
  grep -q "$var" README.md || missing="$missing $var"
done
[ -z "$missing" ] || fail "undocumented variables:$missing"

echo "verify: OK"
