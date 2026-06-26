# CLAUDE.md — frontend

<!-- Module deep-dive. Root CLAUDE.md is the project router; this covers only
     what an engineer changing the React SPA needs. Keep under 32 KB. -->

## Tech stack

Vite 5 · React 18 · TypeScript 5 · react-router 6 · keycloak-js 26 ·
`@diametral/design-system` (Diametral DS). ESM (`"type": "module"`).

## Commands

```bash
# Runs inside docker compose (Vite HMR); no local install needed for edits.
make up                 # frontend at :5173
npm run build           # tsc -b && vite build (typecheck + bundle)
npm run dev             # standalone Vite dev server
```

## Project layout

```
src/
  main.tsx        # Keycloak init gate → render (auth resolves before App mounts)
  App.tsx         # ConsoleLayout shell + react-router routes
  pages/          # one component per route (Dashboard, Items)
  lib/
    keycloak.ts   # keycloak-js instance (Auth Code + PKCE)
    api.ts        # token-injecting fetch — attaches fresh bearer to every call
    config.ts     # reads VITE_* env
    types.ts      # shared TS types
  fonts.css       # Geist + Fraunces (Ufficio falls back to Fraunces)
```

## Conventions & patterns

**Always**

- Call the backend through `lib/api.ts` so the bearer token is attached and
  refreshed — never hand-roll `fetch` with a stale token.
- Use real Diametral components/classes: `import { ... } from
"@diametral/design-system/react"` and the `.ds-*` classes. Don't hand-roll
  styles that the DS already provides.
- Add a page in `src/pages/`, then register it in `ROUTES`/`NAV` and a `<Route>`
  in `src/App.tsx`.

**Never**

- Don't put real secrets in `frontend/.env` — it holds browser-facing `VITE_*`
  (always localhost) and is committed on purpose.
- Don't assume the DS npm bundle ships theme CSS at this version: `main.tsx`
  imports `css/themes/dark.css` + `sepia.css` explicitly. Keep that.

## Auth flow

`main.tsx` gates render on `keycloak.init()` (Authorization Code + PKCE, enforced
on the `web` client). Tokens carry `aud: baseline-api`; `api.ts` refreshes and
injects the access token per request. If auth is failing, suspect the
internal/public Keycloak URL split documented in the root CLAUDE.md, not the SPA.

## Claude Code — relevant agents / commands / skills

- **Agents:** `ecc:typescript-reviewer`
- **Skills:** `frontend-design:frontend-design`, `ecc:frontend-patterns`,
  `design-system`
