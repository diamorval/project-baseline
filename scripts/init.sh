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
# 5. Local environment file (.env) + direnv
# ---------------------------------------------------------------------------
echo
bold "Setting up environment…"
if [ -f .env ]; then
  info "✓ .env already exists (left as-is)"
else
  cp .env.example .env
  info "✓ created .env from .env.example"
fi
# Install direnv if missing (best-effort, platform-aware), then `direnv allow`.
if ! command -v direnv >/dev/null 2>&1; then
  if confirm "direnv not found — install it now (to auto-load .env)?"; then
    if command -v brew >/dev/null 2>&1; then
      brew install direnv
    elif command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update -qq && sudo apt-get install -y direnv
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y direnv
    elif command -v pacman >/dev/null 2>&1; then
      sudo pacman -S --noconfirm direnv
    else
      # Fallback to the official installer (installs into ./bin by default).
      curl -sfL https://direnv.net/install.sh | bash || true
    fi
  fi
fi

if command -v direnv >/dev/null 2>&1; then
  if direnv allow . >/dev/null 2>&1; then
    info "✓ direnv allowed — .env auto-loads when you cd into this directory"
  fi
  # The binary alone isn't enough — direnv needs a one-time shell hook to fire.
  if ! grep -qrs 'direnv hook' "$HOME/.bashrc" "$HOME/.zshrc" \
       "$HOME/.config/fish/config.fish" 2>/dev/null; then
    info "  one-time shell hook (pick your shell):"
    info "    bash → echo 'eval \"\$(direnv hook bash)\"' >> ~/.bashrc"
    info "    zsh  → echo 'eval \"\$(direnv hook zsh)\"'  >> ~/.zshrc"
    info "    fish → echo 'direnv hook fish | source' >> ~/.config/fish/config.fish"
  fi
else
  info "direnv not installed — optional; .env still works for 'docker compose up',"
  info "  which reads it directly. See https://direnv.net to set up shell auto-load."
fi

# ---------------------------------------------------------------------------
# 6. Fresh git history (optional)
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
# 7. Boot (optional)
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
