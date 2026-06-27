# Project Baseline

A ready-to-fork project base: a **React** frontend on the
[Diametral design system](https://github.com/LittleBigCode/design-system), a
**FastAPI** backend, **Postgres**, and **Keycloak** (with its own Postgres) for
authentication — all wired together and started with a single
`docker compose up`. Keycloak's login and emails are themed with Diametral too.

It's intentionally minimal: real auth, a CRUD slice, and a themed shell, with
nothing project-specific baked in. Clone it, `make init`, and start building.

```
┌────────────┐   Bearer token    ┌────────────┐      SQL      ┌────────────┐
│  frontend  │ ────────────────▶ │  backend   │ ───────────▶ │   app-db   │
│ React + DS │                   │  FastAPI   │              │  Postgres  │
│  :5173     │ ◀──────────────── │   :8000    │              └────────────┘
└─────┬──────┘     JSON          └─────┬──────┘
      │                                │ validates JWT (JWKS)
      │ login (OIDC + PKCE)            │
      ▼                                ▼
┌──────────────────────────────────────────────┐    ┌──────────────┐
│            keycloak  :8080 (Diametral theme)  │ ──▶│ keycloak-db  │
└──────────────────────────────────────────────┘    │  Postgres    │
                                                     └──────────────┘
```

## Quick start

First, scaffold your project — `make init` checks prerequisites, asks for a
name, **copies this base into a new sibling folder**, renames everything in the
copy, gives it a fresh git history, and offers to open it in your editor. This
base stays pristine, so you can reuse it for the next project:

```bash
make init                      # asks for a name + folder, copies & renames, prints next steps
```

> The wizard runs anywhere with just bash — and if [`fzf`](https://github.com/junegunn/fzf)
> is installed, its selection menus upgrade to fuzzy pickers automatically.

Already inside a personalised copy, or coming back later? Just start it:

```bash
make up                        # or: docker compose up --build
```

First boot takes a minute or two (image builds + Keycloak imports the realm).
Then open:

| URL                                                   | What                                      |
| ----------------------------------------------------- | ----------------------------------------- |
| http://localhost:5173                                 | The app (redirects you to login)          |
| http://localhost:8000/docs                            | FastAPI Swagger UI                        |
| http://localhost:8080                                 | Keycloak (admin console: `admin`/`admin`) |

Sign in with one of the seeded users:

| Username | Password | Realm roles   |
| -------- | -------- | ------------- |
| `demo`   | `demo`   | `user`        |
| `admin`  | `admin`  | `user`,`admin`|

> If you open the app before Keycloak has finished starting, you'll see a
> "Keycloak unavailable" message — just refresh after a few seconds.

## What's inside

```
project-baseline/
├── docker-compose.yml          # the 5 services
├── Makefile                    # up / down / logs / clean
├── frontend/                   # Vite + React + TS
│   ├── src/
│   │   ├── lib/
│   │   │   ├── keycloak.ts      # keycloak-js client
│   │   │   ├── api.ts           # fetch wrapper (injects/refreshes the token)
│   │   │   └── config.ts        # reads VITE_* env
│   │   ├── main.tsx             # Keycloak init gate, then renders the app
│   │   ├── App.tsx              # ConsoleLayout shell + routes
│   │   └── pages/
│   │       ├── Dashboard.tsx    # stat cards + chart + live item count
│   │       └── Items.tsx        # full CRUD against the backend
│   └── Dockerfile
├── backend/                    # FastAPI
│   ├── app/
│   │   ├── main.py             # app factory, CORS, routers, table create
│   │   ├── config.py           # pydantic-settings
│   │   ├── auth.py             # Keycloak JWT validation (the important bit)
│   │   ├── database.py         # SQLAlchemy engine/session
│   │   ├── models.py           # Item
│   │   ├── schemas.py          # pydantic I/O models
│   │   └── routers/{me,items}.py
│   └── Dockerfile
└── keycloak/
    ├── realm-export.json       # the `baseline` realm (clients, roles, users)
    └── themes/diametral/       # the Diametral login + email theme
```

## How authentication works

1. The SPA uses **`keycloak-js`** with **Authorization Code + PKCE**. On load it
   redirects unauthenticated users to the Keycloak login page (themed with
   Diametral), then comes back with an access token.
2. Every API call carries `Authorization: Bearer <token>` (see
   `frontend/src/lib/api.ts`, which also refreshes the token before it expires).
3. The backend's `get_current_user` dependency (`backend/app/auth.py`) validates
   the token against the realm's **JWKS** signing keys, checking signature,
   issuer, expiry and audience. Routes just add
   `user: CurrentUser = Depends(get_current_user)`.

### The internal-vs-public URL split (why JWT validation works)

The browser reaches Keycloak at `http://localhost:8080`, but the backend reaches
it at `http://keycloak:8080` over the Docker network. The token's `iss` claim is
the **browser** URL, so the backend:

- fetches signing keys from `KEYCLOAK_INTERNAL_URL` (`http://keycloak:8080`), and
- validates the `iss` claim against `KEYCLOAK_ISSUER_URL` (`http://localhost:8080`).

`KC_HOSTNAME=http://localhost:8080` pins Keycloak's issuer so the two always match.

### Audience

The `web` client has an audience mapper that adds `baseline-api` to every
access token; the backend requires it (`KEYCLOAK_AUDIENCE=baseline-api`). Set
that env var to `""` to disable the audience check.

## Developing

New here? [`CONTRIBUTING.md`](CONTRIBUTING.md) covers the hook setup, Make
commands, testing, and the gotchas in one place.

Both app containers hot-reload from bind mounts:

- **Frontend** — edit `frontend/src/**`; Vite HMR updates the browser.
- **Backend** — edit `backend/app/**`; uvicorn `--reload` restarts the server.
- **Keycloak theme** — edit `keycloak/themes/diametral/**` and reload the login
  page (theme caching is disabled in the compose file).

Run pieces outside Docker if you prefer:

```bash
# frontend
cd frontend && npm install && npm run dev

# backend (needs a Postgres + Keycloak reachable; see env vars in compose)
cd backend && python -m venv .venv && . .venv/bin/activate \
  && pip install -r requirements.txt \
  && uvicorn app.main:app --reload
```

## Build your first feature

The `Item` resource is a complete reference slice — model → schema → router →
page. Copy it. To add, say, a `Note`:

- **Backend** — add a `Note` model to `app/models.py` and `NoteCreate`/`NoteOut`
  schemas to `app/schemas.py`, copy `app/routers/items.py` → `notes.py` (swap the
  names; every route already has `Depends(get_current_user)`), then register it in
  `app/main.py`:
  ```python
  from .routers import items, me, notes
  app.include_router(notes.router)
  ```
- **Frontend** — copy `src/pages/Items.tsx` → `Notes.tsx` (adjust the fields and
  the `/api/notes` path; `lib/api.ts` attaches the token), then add it to
  `ROUTES`/`NAV` and a `<Route>` in `src/App.tsx`.
- **Verify** — run `/smoke` in Claude Code, or hit `http://localhost:8000/docs`;
  an endpoint called without a token returns `401`.

A new model needs a fresh DB (`make clean && make up`) — see the Alembic note below.

| You want to…          | Edit…                                                          |
| --------------------- | -------------------------------------------------------------- |
| Add an API route      | `backend/app/routers/` + register in `app/main.py`             |
| Protect a route       | `Depends(get_current_user)` (or `require_role("admin")`)       |
| Add a DB table        | `backend/app/models.py` (then `make clean && make up`)         |
| Add a page            | `frontend/src/pages/` + `ROUTES`/`NAV`/`<Route>` in `App.tsx`  |
| Call the API          | `frontend/src/lib/api.ts` (token-injecting fetch)              |
| Re-import the realm   | edit `keycloak/realm-export.json`, then `make clean && make up`|

## Notes & next steps

- Tables are created on startup via `Base.metadata.create_all` for zero-config
  convenience. Swap in **Alembic** once the schema starts to change.
- The seeded passwords and `admin/admin` console login are for **local dev
  only** — don't ship them. `frontend/.env` is committed on purpose (browser-facing
  localhost config); real secrets must never go there.
- The frontend consumes the design system from the public npm package
  `@diametral/design-system`; the Keycloak theme is vendored under
  `keycloak/themes/diametral/`.
