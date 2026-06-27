#!/usr/bin/env bash
#
# Scaffold a personalised project from this base — WITHOUT touching the base.
#
# Copies the template into a brand-new sibling folder and personalises the copy,
# so this "project-baseline" stays pristine and reusable for the next project.
#
# Workflow (7 steps, shown as [n/7] as it runs):
#   1. check prerequisites (docker + compose + rsync)
#   2. ask for a project name (and confirm the destination folder)
#   3. copy the template into <dest> (clean — no .git, node_modules, caches, .env)
#   4. rename the copy everywhere it must stay in sync (scripts/rename.sh)
#   5. set up the copy's .env (+ direnv)
#   6. give the copy a fresh git history
#   7. optionally open the new folder in your editor (cursor / code / …)
#
#   usage:  make init      (or: bash scripts/init.sh)
#
# UI: pure-bash by design so it runs on a fresh machine; `fzf`, when present, is
# used as a progressive enhancement for the selection menus (graceful fallback).
# Respects NO_COLOR. Interactive by design — naming is part of init.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# ===========================================================================
# TUI toolkit — colours, banner, step counter, status lines, prompts, spinner
# ===========================================================================

# Colours only when stdout is a TTY and NO_COLOR is unset (https://no-color.org).
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'
  RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; CYN=$'\033[36m'
  RST=$'\033[0m'
else
  BOLD=''; DIM=''; RED=''; GRN=''; YLW=''; CYN=''; RST=''
fi

# A horizontal rule sized to the banner's interior width.
RULE_W=45
RULE="$(printf '─%.0s' $(seq 1 "$RULE_W"))"

banner() { # banner "title"  — framed header (title must be ASCII for alignment)
  printf '\n  %s╭%s╮%s\n'        "$CYN" "$RULE" "$RST"
  printf   '  %s│%s %s%-*s%s %s│%s\n' "$CYN" "$RST" "$BOLD" "$((RULE_W - 2))" "$1" "$RST" "$CYN" "$RST"
  printf   '  %s╰%s╯%s\n'        "$CYN" "$RULE" "$RST"
}

STEP=0; TOTAL=7
step() { # step "title" — bumps the counter and prints a section header
  STEP=$((STEP + 1))
  printf '\n%s%s[%d/%d]%s %s%s%s\n' "$BOLD" "$CYN" "$STEP" "$TOTAL" "$RST" "$BOLD" "$1" "$RST"
}

ok()    { printf '  %s✓%s %s\n' "$GRN" "$RST" "$1"; }
warn()  { printf '  %s⚠%s %s\n' "$YLW" "$RST" "$1"; }
fail()  { printf '  %s✗%s %s\n' "$RED" "$RST" "$1" >&2; }
info()  { printf '  %s\n' "$1"; }
note()  { printf '  %s%s%s\n' "$DIM" "$1" "$RST"; }
field() { printf '  %s%-26s%s %s\n' "$DIM" "$1" "$RST" "$2"; } # label + value

die() { fail "$1"; exit 1; }

# ask "prompt" ["default"] -> echoes the answer (default applied on empty input).
ask() {
  local prompt="$1" def="${2:-}" reply
  if [ -n "$def" ]; then
    read -r -p "$(printf '  %s❯%s %s %s[%s]%s ' "$CYN" "$RST" "$prompt" "$DIM" "$def" "$RST")" reply
    printf '%s' "${reply:-$def}"
  else
    read -r -p "$(printf '  %s❯%s %s ' "$CYN" "$RST" "$prompt")" reply
    printf '%s' "$reply"
  fi
}

# confirm "prompt" — default no; returns 0 for yes. Auto-no when not a TTY.
confirm() {
  [ -t 0 ] || return 1
  local reply
  read -r -p "$(printf '  %s❯%s %s %s[y/N]%s ' "$CYN" "$RST" "$1" "$DIM" "$RST")" reply
  [[ "$reply" =~ ^[Yy]$ ]]
}

# choose "fzf-prompt" item...  -> echoes the chosen item (empty if cancelled).
# Uses fzf when available (fuzzy, arrow-key select); else a numbered menu.
choose() {
  local prompt="$1"; shift
  local items=("$@")
  if command -v fzf >/dev/null 2>&1; then
    printf '%s\n' "${items[@]}" \
      | fzf --height='~40%' --reverse --border=rounded --no-multi \
            --prompt="$prompt " --color='prompt:cyan,pointer:cyan' 2>/dev/tty \
      || true
  else
    local i=1 it
    for it in "${items[@]}"; do
      printf '  %s%d)%s %s\n' "$CYN" "$i" "$RST" "$it" >&2
      i=$((i + 1))
    done
    local reply
    read -r -p "$(printf '  %s❯%s choose [1]: ' "$CYN" "$RST")" reply
    reply="${reply:-1}"
    if [[ "$reply" =~ ^[0-9]+$ ]] && [ "$reply" -ge 1 ] && [ "$reply" -le "${#items[@]}" ]; then
      printf '%s' "${items[$((reply - 1))]}"
    fi
  fi
}

# spinner_run "message" cmd...  — run a command while animating a spinner;
# print ✓/✗ on completion and, on failure, dump its captured output then exit.
spinner_run() {
  local msg="$1"; shift
  if [ ! -t 1 ]; then "$@"; ok "$msg"; return; fi  # non-TTY: just run, no animation
  local log; log="$(mktemp)"
  "$@" >"$log" 2>&1 &
  local pid=$! rc=0
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏') i=0
  printf '\033[?25l' 2>/dev/null || true  # hide cursor
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r  %s%s%s %s' "$CYN" "${frames[i]}" "$RST" "$msg"
    i=$(((i + 1) % ${#frames[@]}))
    sleep 0.08
  done
  printf '\033[?25h' 2>/dev/null || true  # restore cursor
  wait "$pid" || rc=$?
  if [ "$rc" -eq 0 ]; then
    printf '\r  %s✓%s %s\033[K\n' "$GRN" "$RST" "$msg"
    rm -f "$log"
  else
    printf '\r  %s✗%s %s\033[K\n' "$RED" "$RST" "$msg"
    cat "$log" >&2; rm -f "$log"
    exit "$rc"
  fi
}

# Friendly label for an editor launcher command.
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

# ===========================================================================
banner "new project setup"

# ---------------------------------------------------------------------------
step "Checking prerequisites"
# ---------------------------------------------------------------------------
command -v docker  >/dev/null 2>&1 || die "Docker not found — install Docker Desktop, then re-run."
docker compose version >/dev/null 2>&1 || die "'docker compose' not available (need Compose v2)."
command -v rsync   >/dev/null 2>&1 || die "rsync not found — install: brew install rsync / apt-get install rsync."
ok "docker · docker compose · rsync"
if command -v fzf >/dev/null 2>&1; then
  ok "fzf detected — menus use fuzzy select"
else
  note "fzf not found — menus fall back to numbered lists (optional: brew install fzf)"
fi

# ---------------------------------------------------------------------------
step "Name your project"
# ---------------------------------------------------------------------------
[ -t 0 ] || die "'make init' is interactive — run it in a terminal."
NAME="$(ask 'Project name (e.g. acme):')"

SLUG="$(printf '%s' "$NAME" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//')"
TITLE="$(printf '%s' "$SLUG" | perl -ne 'print join(" ", map { ucfirst } split /-/)')"
[ -n "$SLUG" ] || die "'$NAME' produced an empty slug; use letters/numbers."

# Default destination is a sibling folder next to this base, named after the slug.
DEFAULT_DEST="$(cd .. && pwd)/$SLUG"
DEST="$(ask 'Destination folder:' "$DEFAULT_DEST")"
# Normalise to an absolute path (the parent must already exist).
DEST_PARENT="$(cd "$(dirname "$DEST")" 2>/dev/null && pwd || true)"
[ -n "$DEST_PARENT" ] || die "parent directory of '$DEST' does not exist."
DEST="$DEST_PARENT/$(basename "$DEST")"

[ "$DEST" != "$ROOT" ] || die "destination must be a new folder, not the template itself."
[ ! -e "$DEST" ] || die "'$DEST' already exists — pick a folder that doesn't exist yet."

echo
field "destination"             "$DEST"
field "slug (realm, env, pkg)"  "$SLUG"
field "audience"                "$SLUG-api"
field "brand (UI)"              "$TITLE"
echo
confirm "Proceed?" || { note "Aborted."; exit 0; }

# ---------------------------------------------------------------------------
step "Copying template"
# ---------------------------------------------------------------------------
# Exclude everything regenerable or machine-local: VCS, deps, caches, build
# artifacts, the local .env, and personal Claude settings. The copy is a clean
# checkout you then personalise.
spinner_run "copied $SLUG (template left untouched)" \
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

# Everything below operates on the COPY.
cd "$DEST"

# ---------------------------------------------------------------------------
step "Renaming baseline → $SLUG"
# ---------------------------------------------------------------------------
# rename.sh finds files with `git grep`, so stage the copy in a throwaway git
# index first. History is reset cleanly in the next step regardless.
git init -q
git add -A
bash scripts/rename.sh "$NAME" >/dev/null
ok "renamed (brand: $TITLE · audience: $SLUG-api)"

# ---------------------------------------------------------------------------
step "Setting up environment"
# ---------------------------------------------------------------------------
cp .env.example .env
ok "created .env from .env.example"
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
    ok "direnv allowed — .env auto-loads when you cd into this directory"
  fi
  # The binary alone isn't enough — direnv needs a one-time shell hook to fire.
  if ! grep -qrs 'direnv hook' "$HOME/.bashrc" "$HOME/.zshrc" \
       "$HOME/.config/fish/config.fish" 2>/dev/null; then
    note "one-time shell hook (pick your shell):"
    note "  bash → echo 'eval \"\$(direnv hook bash)\"' >> ~/.bashrc"
    note "  zsh  → echo 'eval \"\$(direnv hook zsh)\"'  >> ~/.zshrc"
    note "  fish → echo 'direnv hook fish | source' >> ~/.config/fish/config.fish"
  fi
else
  note "direnv not installed — optional; .env still works for 'docker compose up',"
  note "  which reads it directly. See https://direnv.net to set up shell auto-load."
fi

# ---------------------------------------------------------------------------
step "Initialising fresh git history"
# ---------------------------------------------------------------------------
# The copy carries a throwaway index from the rename step — reset it to a single
# clean commit so the new project starts with its own history (not the base's).
# --no-verify: the bootstrap commit predates any real work, so it must not be
# gated by the template's own hooks (e.g. no-commit-to-branch on 'main').
rm -rf .git
git init -q
git add -A
git commit --no-verify -qm "Initial commit"
ok "fresh git history (1 commit)"

# ---------------------------------------------------------------------------
step "Open in an editor"
# ---------------------------------------------------------------------------
FOUND_CMDS=(); FOUND_NAMES=()
for e in cursor code codium windsurf zed subl idea webstorm; do
  if command -v "$e" >/dev/null 2>&1; then
    FOUND_CMDS+=("$e"); FOUND_NAMES+=("$(editor_name "$e")")
  fi
done

if [ "${#FOUND_CMDS[@]}" -eq 0 ]; then
  note "No editor launcher on PATH (cursor/code/zed/…) — open $DEST manually."
else
  PICK="$(choose 'Open in >' "${FOUND_NAMES[@]}" "Don't open")"
  if [ -n "$PICK" ] && [ "$PICK" != "Don't open" ]; then
    for idx in "${!FOUND_NAMES[@]}"; do
      if [ "${FOUND_NAMES[$idx]}" = "$PICK" ]; then
        if "${FOUND_CMDS[$idx]}" "$DEST" >/dev/null 2>&1; then
          ok "opened in $PICK"
        else
          warn "couldn't launch $PICK — open $DEST manually."
        fi
        break
      fi
    done
  else
    note "not opening — $DEST is ready when you are."
  fi
fi

# ---------------------------------------------------------------------------
echo
banner "$SLUG is ready"
cat <<EOF

  Your new project lives at:
    ${BOLD}$DEST${RST}

  Get it running:
    ${CYN}cd "$DEST"${RST}
    ${CYN}make clean && make up${RST}   ${DIM}# wipe DB volumes so the '$SLUG' realm imports${RST}

  Then open ${BOLD}http://localhost:5173${RST} and sign in as ${BOLD}demo${RST}/${BOLD}demo${RST}.
  See the README ("Build your first feature") to add your first feature.
EOF
