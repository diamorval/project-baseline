#!/usr/bin/env bash
#
# Initialise a personalised project from this base.
#
# Runs the full first-time setup workflow:
#   1. check prerequisites (docker + compose)
#   2. ask for a project name
#   3. rename the project everywhere it must stay in sync (scripts/rename.sh)
#   4. optionally reset git history to a clean initial commit
#   5. optionally build + start the stack (make clean && make up)
#
#   usage:  make init      (or: bash scripts/init.sh)
#
# Interactive by design — naming is part of init. To rename non-interactively
# (e.g. in a script), use scripts/rename.sh directly.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
info() { printf '  %s\n' "$1"; }

# Prompt helper: ask "$1", default no; returns 0 for yes. Auto-no when not a TTY.
confirm() {
  if [ ! -t 0 ]; then return 1; fi
  local reply
  read -r -p "$1 [y/N] " reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# ---------------------------------------------------------------------------
# 1. Prerequisites
# ---------------------------------------------------------------------------
bold "Checking prerequisites…"
if ! command -v docker >/dev/null 2>&1; then
  echo "  ✗ Docker not found — install Docker Desktop, then re-run." >&2
  exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
  echo "  ✗ 'docker compose' not available (need Compose v2)." >&2
  exit 1
fi
info "✓ docker + docker compose"

# ---------------------------------------------------------------------------
# 2. Already initialised?
# ---------------------------------------------------------------------------
if ! git grep -qI -e baseline -e Baseline -- . ':!scripts/' >/dev/null 2>&1; then
  bold "This project looks already initialised (no 'baseline' references left)."
  confirm "Rename it again anyway?" || { info "Nothing to do."; exit 0; }
fi

# ---------------------------------------------------------------------------
# 3. Project name
# ---------------------------------------------------------------------------
if [ ! -t 0 ]; then
  echo "error: 'make init' is interactive — run it in a terminal." >&2
  exit 1
fi
read -r -p "Project name (e.g. acme): " NAME

SLUG="$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')"
TITLE="$(printf '%s' "$SLUG" | perl -ne 'print join(" ", map { ucfirst } split /-/)')"
if [ -z "$SLUG" ]; then
  echo "error: '$NAME' produced an empty slug; use letters/numbers." >&2
  exit 1
fi

echo
bold "About to configure:"
info "slug (realm, env, package): $SLUG"
info "audience:                   $SLUG-api"
info "brand (UI):                 $TITLE"
echo
if ! confirm "Proceed?"; then info "Aborted."; exit 0; fi

# ---------------------------------------------------------------------------
# 4. Rename everything
# ---------------------------------------------------------------------------
echo
bold "Renaming…"
bash scripts/rename.sh "$NAME"

# ---------------------------------------------------------------------------
# 5. Fresh git history (optional)
# ---------------------------------------------------------------------------
echo
if confirm "Reset git history to a single 'Initial commit'?"; then
  rm -rf .git
  git init -q
  git add -A
  git commit -qm "Initial commit"
  info "✓ fresh git history"
else
  info "kept existing git history (changes are unstaged — commit when ready)"
fi

# ---------------------------------------------------------------------------
# 6. Boot (optional)
# ---------------------------------------------------------------------------
echo
if confirm "Build and start the stack now (make clean && make up)?"; then
  make clean
  make up
else
  cat <<EOF

Done. When you're ready to run it:

  make clean && make up      # wipe DB volumes so the '$SLUG' realm imports

Then open http://localhost:5173 and sign in as demo/demo.
See the README ("Build your first feature") to add your first feature.
EOF
fi
