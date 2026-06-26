#!/usr/bin/env bash
# PreToolUse guard (Edit|Write): block writing real secrets into committed .env
# files. frontend/.env is committed on purpose but must hold only browser-facing
# VITE_* values — never real credentials. Exit 2 = blocking (stderr → Claude).
set -euo pipefail

input="$(cat)"

# Fail open: if the payload doesn't parse, never block a legitimate write.
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)" || exit 0
[ -n "$file_path" ] || exit 0

# Only guard .env files (.env, .env.local, frontend/.env, …); skip .env.example.
case "$file_path" in
  *.env|*.env.*) ;;
  *) exit 0 ;;
esac
case "$file_path" in
  *.example|*.sample|*.template) exit 0 ;;
esac

# Inspect whatever the tool is about to write: Write→content, Edit→new_string.
content="$(printf '%s' "$input" \
  | jq -r '.tool_input.content // .tool_input.new_string // empty' 2>/dev/null)" || exit 0
[ -n "$content" ] || exit 0

# Real-secret signatures: private keys, AWS keys, bearer/JWT, or a
# secret/password/token/api_key assignment with a non-trivial, non-VITE value.
if printf '%s' "$content" | grep -qiE \
  -e 'BEGIN [A-Z ]*PRIVATE KEY' \
  -e 'AKIA[0-9A-Z]{16}' \
  -e 'eyJ[A-Za-z0-9_-]{20,}\.' \
  -e '^(export[[:space:]]+)?(([A-Za-z0-9_]*_)?(SECRET|PASSWORD|TOKEN|API_?KEY|PRIVATE_KEY))[[:space:]]*=[[:space:]]*["'\'']?[^[:space:]"'\'']{8,}'
then
  # VITE_-only assignments are browser-facing and allowed.
  if printf '%s' "$content" | grep -iE \
    '(SECRET|PASSWORD|TOKEN|API_?KEY|PRIVATE_KEY)[[:space:]]*=' \
    | grep -qvE '^(export[[:space:]]+)?VITE_'; then
    echo "BLOCKED: '$file_path' appears to contain a real secret." >&2
    echo "Committed .env files must hold only browser-facing VITE_* values." >&2
    echo "Put real secrets in an untracked .env (gitignored) or a vault." >&2
    exit 2
  fi
fi

exit 0
