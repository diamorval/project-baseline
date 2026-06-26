#!/usr/bin/env bash
# Pre-push gate: full frontend typecheck (the same `tsc -b` the build runs).
# Guarded so it skips cleanly when deps aren't installed (docker-based dev) —
# gates real type errors without a false block on a fresh clone.
set -euo pipefail
cd "$(dirname "$0")/../frontend"

if [ ! -d node_modules ]; then
  echo "skip: frontend deps not installed (run: cd frontend && npm install)"
  exit 0
fi

exec npx tsc -b
