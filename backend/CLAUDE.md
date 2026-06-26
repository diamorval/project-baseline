# CLAUDE.md — backend

<!-- Module deep-dive. Root CLAUDE.md is the project router; this covers only
     what an engineer changing the FastAPI service needs. Keep under 32 KB. -->

## Tech stack

FastAPI 0.138 · SQLAlchemy 2.0 · pydantic 2 / pydantic-settings · python-jose
(JWT) · psycopg2 · httpx · uvicorn. Python 3.12, no lockfile — runtime pinned in
`requirements.txt`, test-only deps (pytest) in `requirements-dev.txt`.

## Commands

```bash
# Runs inside docker compose (see root Makefile); no local venv assumed.
make up                       # starts backend at :8000 (uvicorn --reload)
make test                     # pytest in a one-off container (backend/tests/)
docker compose logs -f backend
# Swagger: http://localhost:8000/docs
```

## Project layout

```
app/
  main.py         # app factory: CORS, create_all, router includes
  auth.py         # Keycloak JWT validation — the core (JWKS + iss + exp + aud)
  config.py       # pydantic-settings (env-driven)
  database.py     # engine + SessionLocal + get_db dependency
  models.py       # SQLAlchemy models (create_all'd on startup, no Alembic)
  schemas.py      # pydantic request/response models
  routers/        # one APIRouter per resource (me, items)
tests/            # pytest smoke suite (test_smoke.py) — DB-free, see "Tests"
pytest.ini        # pythonpath=. + testpaths=tests
```

## Conventions & patterns

**Always**

- Protect routes with `user: CurrentUser = Depends(get_current_user)`; gate by
  role with `Depends(require_role("admin"))` (`app/auth.py`).
- Add a router as `app/routers/<x>.py` (an `APIRouter`) and include it in
  `app/main.py`.
- Keep request/response shapes in `schemas.py`; keep ORM in `models.py`.

**Never**

- Don't unify `KEYCLOAK_INTERNAL_URL` (compose network) with
  `KEYCLOAK_ISSUER_URL` (browser host) — auth breaks. See root CLAUDE.md "Auth".
- Don't expect a `models.py` change to migrate an existing DB: tables are
  `create_all`'d, so schema changes only land on a fresh DB (`make clean`).
  Introduce Alembic before the schema matters.

## Auth gate

`get_current_user` validates the bearer JWT against the realm JWKS (fetched from
`KEYCLOAK_INTERNAL_URL`), checking signature + issuer (`KEYCLOAK_ISSUER_URL`) +
expiry + audience (`KEYCLOAK_AUDIENCE`, default `baseline-api`; `""` disables).
This split is deliberate — the browser and the backend reach Keycloak by
different hostnames but must agree on `iss`.

## Tests

`tests/` runs under pytest (`make test`, or `pytest` from `backend/`). The smoke
suite is **DB-free on purpose**: `create_all` runs inside the FastAPI `lifespan`,
and `TestClient(app)` used *without* a `with` block never fires it — so tests hit
`/health` and the auth gate without a Postgres. The moment a test needs the DB,
add a Postgres `service` to the CI `tests` job and use the TestClient as a
context manager.

## Claude Code — relevant agents / commands / skills

- **Agents:** `ecc:fastapi-reviewer`, `ecc:security-reviewer`
- **Commands:** `/smoke`
- **Skills:** `ecc:fastapi-patterns`, `ecc:python-testing`
