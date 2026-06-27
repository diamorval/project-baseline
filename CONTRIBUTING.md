# Contributing

Thanks for working on Baseline. This guide covers the day-to-day workflow; the
[README](README.md) is the architectural tour and `CLAUDE.md` is the dense,
agent-facing version.

## Prerequisites

- **Docker** + **Docker Compose** — the whole stack runs in containers.
- **Python 3.12+** and **[pre-commit](https://pre-commit.com/)** (`uv tool install
  pre-commit` or `pip install pre-commit`) — for the git hooks below.
- **Node 20+** — only if you run the frontend outside Docker.

## First-time setup

After cloning, install the git hooks once — `.git/hooks/` isn't tracked, so each
contributor runs this themselves:

```bash
pre-commit install --hook-type pre-commit --hook-type pre-push --hook-type commit-msg
```

Then bring the stack up:

```bash
make up            # build + start everything; first boot ~1–2 min (realm import)
```

## Everyday commands

| Command       | What it does                                                      |
| ------------- | ----------------------------------------------------------------- |
| `make up`     | Build (if needed) and start the whole stack                       |
| `make down`   | Stop containers, **keep** DB volumes                              |
| `make clean`  | Stop **and wipe** DB volumes (required to re-import the realm)     |
| `make logs`   | Tail logs for all services                                        |
| `make restart`| Recreate containers                                               |
| `make init`   | Scaffold a personalised copy into a new folder (keeps this base pristine) |

Ports: frontend `:5173`, backend `:8000` (`/docs` = Swagger), Keycloak `:8080`
(admin `admin`/`admin`), app-db `:5432`. Both app containers hot-reload from bind
mounts — no rebuild for source edits.

## Code quality (hooks)

The hooks run automatically once installed:

- **On commit** — Ruff (format + lint) on `backend/`, Prettier on `frontend/`,
  `gitleaks` secret scan, and baseline hygiene (trailing whitespace, JSON/YAML
  validity, large-file and private-key guards). Auto-fixers rewrite files in
  place; if a hook reports "Failed" after fixing, re-`git add` and commit again.
- **On push** — backend byte-compile and a frontend `tsc -b` typecheck (the
  typecheck skips cleanly if you haven't run `npm install` in `frontend/`).

Run them by hand anytime:

```bash
pre-commit run --all-files                       # commit-time hooks
pre-commit run --hook-stage pre-push --all-files # push-time gate
```

> Direct commits to `main`/`master` are blocked by `no-commit-to-branch` — work
> on a feature branch and open a PR.

## Commits & versioning (Conventional Commits)

Commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/)
(`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, …). The `commit-msg` hook checks
this locally and CI re-checks every PR's commits.

This drives versioning: a maintainer cuts a release with

```bash
make release        # cz bump → version + CHANGELOG.md + git tag (needs commitizen)
```

which bumps the version (in `.cz.toml`, `frontend/package.json`, `backend/app/main.py`),
regenerates `CHANGELOG.md`, and tags — all from the commit history. Publishing the
tag (deploy / package release) is a separate CD step, intentionally not wired here.

## Testing your change

Run the backend unit tests (no running stack needed — they don't touch a DB):

```bash
make test                          # pytest in a one-off backend container
# or locally: cd backend && pip install -r requirements.txt -r requirements-dev.txt && pytest
```

`backend/tests/` starts with a smoke suite (health endpoint, the auth gate);
add cases there as you build. CI runs the same `pytest` on every push and PR.

For an end-to-end check against the *running* stack, use **`/smoke`** in Claude
Code (or follow `.claude/commands/smoke.md`): it mints a Keycloak token for
`demo`, calls `/api/me` with and without it (expect `200` then `403`), and
round-trips an item through `/api/items`.

The README's **"Build your first feature"** section walks the `Item` reference
slice (model → schema → router → page) you copy to add new resources.

## Gotchas

- **Two Postgres databases.** `app-db` holds app data; `keycloak-db` is
  Keycloak's own store — don't cross them.
- **Realm edits need a wipe.** Editing `keycloak/realm-export.json` has no effect
  until you `make clean` — `--import-realm` skips a realm that already exists.
- **Schema changes need a fresh DB.** Tables are `create_all`'d on startup (no
  Alembic yet), so a `models.py` change only applies after `make clean && make up`.
- **Don't unify the Keycloak URLs.** The internal (`http://keycloak:8080`) vs
  public (`http://localhost:8080`) split is deliberate — see the README's
  "internal-vs-public URL split" section. Unifying them breaks JWT validation.
- **`frontend/.env` is committed on purpose** (browser-facing `VITE_*` localhost
  config). Real secrets must never go there — a commit hook blocks it.
