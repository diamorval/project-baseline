#!/usr/bin/env bash
# PostToolUse formatter (Edit|Write): keep the tree always-clean by formatting
# the file Claude just touched, mirroring .pre-commit-config.yaml exactly so the
# in-session format and the commit-time gate never disagree.
#   - backend/*.py            → ruff --fix (E,W,F,I,UP) then ruff format, len 100
#   - frontend/*.{ts,tsx,css,json,md} → prettier --write
# Best-effort and non-blocking: always exit 0. If no formatter resolves (e.g. a
# fresh clone with docker-based dev), it silently no-ops.
set -uo pipefail

input="$(cat)"

file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" || exit 0
[ -n "$file_path" ] || exit 0
[ -f "$file_path" ] || exit 0

# Resolve the path relative to the project root so the backend/frontend prefix
# checks work regardless of the tool's reported absolute vs relative path.
root="${CLAUDE_PROJECT_DIR:-$PWD}"
rel="${file_path#"$root"/}"

# --- Python (backend/) — auto-fix then format, pinned to the pre-commit rev ---
run_ruff() {
  if command -v ruff >/dev/null 2>&1; then
    ruff check --fix --select E,W,F,I,UP --line-length 100 "$1" >/dev/null 2>&1 || true
    ruff format --line-length 100 "$1" >/dev/null 2>&1 || true
  elif command -v uvx >/dev/null 2>&1; then
    uvx ruff@0.8.4 check --fix --select E,W,F,I,UP --line-length 100 "$1" >/dev/null 2>&1 || true
    uvx ruff@0.8.4 format --line-length 100 "$1" >/dev/null 2>&1 || true
  else
    return 1
  fi
}

# --- Web (frontend/) — Prettier, preferring a locally-installed binary ---
run_prettier() {
  local local_bin="$root/frontend/node_modules/.bin/prettier"
  if [ -x "$local_bin" ]; then
    "$local_bin" --write "$1" >/dev/null 2>&1 || true
  elif command -v prettier >/dev/null 2>&1; then
    prettier --write "$1" >/dev/null 2>&1 || true
  elif command -v npx >/dev/null 2>&1; then
    npx --yes prettier@3.4.2 --write "$1" >/dev/null 2>&1 || true
  else
    return 1
  fi
}

case "$rel" in
  backend/*.py)
    run_ruff "$file_path" && echo "Formatted $rel (ruff)" >&2
    ;;
  frontend/*.ts|frontend/*.tsx|frontend/*.css|frontend/*.json|frontend/*.md)
    run_prettier "$file_path" && echo "Formatted $rel (prettier)" >&2
    ;;
esac

exit 0
