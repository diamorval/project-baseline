#!/usr/bin/env bash
#
# Scaffold a personalised project from this base.
#
#
# Workflow:
#   1. check prerequisites (docker + compose + rsync)
#   2. ask for a project name (and confirm the destination folder)
#   3. copy the template into <dest> (clean — no .git, node_modules, caches, .env)
#   4. rename the copy everywhere it must stay in sync (scripts/rename.sh)
#   5. set up the copy's .env (+ direnv) and a fresh git history
#   6. optionally open the new folder in your editor (cursor / code / …)
#   7. optionally build + start the stack from the new folder
#
#   usage:  make init      (or: bash scripts/init.sh)
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
if ! command -v rsync >/dev/null 2>&1; then
  echo "  ✗ rsync not found — needed to copy the template (install: brew install rsync / apt-get install rsync)." >&2
  exit 1
fi
info "✓ docker + docker compose + rsync"

# ---------------------------------------------------------------------------
# 2. Project name + destination folder
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

# Default destination is a sibling folder next to this base, named after the slug.
DEFAULT_DEST="$(cd .. && pwd)/$SLUG"
read -r -p "Destination folder [$DEFAULT_DEST]: " DEST
DEST="${DEST:-$DEFAULT_DEST}"
# Normalise to an absolute path (the parent must already exist).
DEST_PARENT="$(cd "$(dirname "$DEST")" 2>/dev/null && pwd || true)"
if [ -z "$DEST_PARENT" ]; then
  echo "error: parent directory of '$DEST' does not exist." >&2
  exit 1
fi
DEST="$DEST_PARENT/$(basename "$DEST")"

if [ "$DEST" = "$ROOT" ]; then
  echo "error: destination must be a new folder, not the template itself." >&2
  exit 1
fi
if [ -e "$DEST" ]; then
  echo "error: '$DEST' already exists — pick a folder that doesn't exist yet." >&2
  exit 1
fi

echo
bold "About to scaffold a new project:"
info "destination:                $DEST"
info "slug (realm, env, package): $SLUG"
info "audience:                   $SLUG-api"
info "brand (UI):                 $TITLE"
echo
if ! confirm "Proceed?"; then info "Aborted."; exit 0; fi

# ---------------------------------------------------------------------------
# 3. Copy the template into the new folder (clean)
# ---------------------------------------------------------------------------
echo
bold "Copying template → $DEST …"
# Exclude everything regenerable or machine-local: VCS, deps, caches, build
# artifacts, the local .env, and personal Claude settings. The copy is a clean
# checkout you then personalise.
rsync -a \
  --exclude '.git/' \
  --exclude 'node_modules/' \
  --exclude '.venv/' \
  --exclude 'venv/' \
  --exclude '__pycache__/' \
  --exclude '*.py[cod]' \
  --exclude '.pytest_cache/' \
  --exclude '.mypy_cache/' \
  --exclude '.ruff_cache/' \
  --exclude '.direnv/' \
  --exclude 'frontend/dist/' \
  --exclude '*.tsbuildinfo' \
  --exclude 'frontend/vite.config.js' \
  --exclude 'frontend/vite.config.d.ts' \
  --exclude '/.env' \
  --exclude '.env.local' \
  --exclude '*.env.local' \
  --exclude '.claude/settings.local.json' \
  --exclude '.DS_Store' \
  "$ROOT/" "$DEST/"
info "✓ copied (template left untouched)"

# Everything below operates on the COPY.
cd "$DEST"

# ---------------------------------------------------------------------------
# 4. Rename everything in the copy
# ---------------------------------------------------------------------------
# rename.sh finds files with `git grep`, so stage the copy in a throwaway git
# index first. History is reset cleanly in step 6 regardless.
echo
bold "Renaming…"
git init -q
git add -A
bash scripts/rename.sh "$NAME"

# ---------------------------------------------------------------------------
# 5. Local environment file (.env) + direnv
# ---------------------------------------------------------------------------
echo
bold "Setting up environment…"
cp .env.example .env
info "✓ created .env from .env.example"
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
# 6. Fresh git history for the new project
# ---------------------------------------------------------------------------
echo
rm -rf .git
git init -q
git add -A
git commit --no-verify -qm "Initial commit"
info "✓ fresh git history"

# ---------------------------------------------------------------------------
# 7. Open in an editor (optional)
# ---------------------------------------------------------------------------
echo
# Friendly label for an editor launcher.
editor_name() {
  case "$1" in
    cursor)   echo "Cursor" ;;
    code)     echo "VS Code" ;;
    codium)   echo "VSCodium" ;;
    windsurf) echo "Windsurf" ;;
    zed)      echo "Zed" ;;
    subl)     echo "Sublime Text" ;;
    idea)     echo "IntelliJ IDEA" ;;
    webstorm) echo "WebStorm" ;;
    *)        echo "$1" ;;
  esac
}

# Collect every editor launcher that's actually on PATH (preference order).
FOUND_EDITORS=()
for e in cursor code codium windsurf zed subl idea webstorm; do
  command -v "$e" >/dev/null 2>&1 && FOUND_EDITORS+=("$e")
done

if [ "${#FOUND_EDITORS[@]}" -eq 0 ]; then
  info "No editor launcher found on PATH (cursor/code/zed/…) — open $DEST manually."
else
  bold "Open the new project in an editor?"
  i=1
  for e in "${FOUND_EDITORS[@]}"; do
    info "$i) $(editor_name "$e")"
    i=$((i + 1))
  done
  info "n) don't open"
  read -r -p "Choose [1]: " CHOICE
  CHOICE="${CHOICE:-1}"
  if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#FOUND_EDITORS[@]}" ]; then
    PICK="${FOUND_EDITORS[$((CHOICE - 1))]}"
    "$PICK" "$DEST" >/dev/null 2>&1 \
      && info "✓ opened in $(editor_name "$PICK")" \
      || info "couldn't launch $(editor_name "$PICK") — open $DEST manually."
  else
    info "not opening — $DEST is ready when you are."
  fi
fi

# ---------------------------------------------------------------------------
# 8. Boot (optional)
# ---------------------------------------------------------------------------
echo
if confirm "Build and start the stack now from $DEST (make clean && make up)?"; then
  make clean
  make up
else
  cat <<EOF

Done. Your new project lives at:

  $DEST

Get it running:

  cd "$DEST"
  make clean && make up      # wipe DB volumes so the '$SLUG' realm imports

Then open http://localhost:5173 and sign in as demo/demo.
See the README ("Build your first feature") to add your first feature.
EOF
fi
