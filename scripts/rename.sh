#!/usr/bin/env bash
#
# Rename this project base from "baseline" to your own name, in one shot.
#
# It rewrites the project identity everywhere it must stay in sync: the Keycloak
# realm + audience, the docker compose project name, the frontend/backend env
# defaults, package metadata, the displayed brand, and the docs.
#
#   usage:  bash scripts/rename.sh <new-name>
#   example: bash scripts/rename.sh acme
#
# After running, wipe the Keycloak DB volume so the new realm imports:
#
#   make clean && make up
#
set -euo pipefail

NEW="${1:-}"
if [ -z "$NEW" ]; then
  echo "usage: bash scripts/rename.sh <new-name>   (e.g. bash scripts/rename.sh acme)" >&2
  exit 1
fi

# slug = lowercase, kebab-case (used for realm, audience, env, package names)
SLUG="$(printf '%s' "$NEW" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')"
# title = each slug segment capitalised, joined with spaces (the displayed brand)
TITLE="$(printf '%s' "$SLUG" | perl -ne 'print join(" ", map { ucfirst } split /-/)')"

if [ -z "$SLUG" ]; then
  echo "error: '$NEW' produced an empty slug; use letters/numbers, e.g. 'acme'" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Every tracked text file that mentions the project name (minus the scripts,
# which document "baseline" on purpose).
FILES="$(git grep -lI -e baseline -e Baseline -- . ':!scripts/' || true)"
if [ -z "$FILES" ]; then
  echo "nothing to rename — no 'baseline' references found." >&2
  exit 0
fi

# Order matters: replace the compound 'baseline-api' before the bare word.
# \b keeps us from touching substrings inside unrelated words.
echo "$FILES" | while IFS= read -r f; do
  [ -n "$f" ] || continue
  perl -pi -e "s/baseline-api/${SLUG}-api/g; s/\bbaseline\b/${SLUG}/g; s/\bBaseline\b/${TITLE}/g" "$f"
  echo "  updated $f"
done

cat <<EOF

Renamed: baseline -> ${SLUG}   (brand: ${TITLE}, audience: ${SLUG}-api)

Next:
  1) make clean && make up      # re-import the new '${SLUG}' realm (wipes DB volumes)
  2) (optional) rename the repo directory itself, then 'cd' back in

The seeded dev users (demo/demo, admin/admin) are unchanged.
EOF
