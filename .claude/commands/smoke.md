---
description: End-to-end auth + API smoke test against the running stack
---

Run a non-destructive end-to-end smoke test of the running stack (start it first
with `make up` if needed):

1. Mint a Keycloak access token for `demo`/`demo` via the `web` client
   (password grant) at `http://localhost:8080/realms/baseline`.
2. Decode and report the token's `iss`, `aud`, and `realm_access.roles`.
3. `GET http://localhost:8000/api/me` **with** the token → expect `200` + the
   user JSON; **without** the token → expect `401`.
4. `POST` a throwaway item to `/api/items` then `GET /api/items` → expect the
   item to come back, owner-scoped to the demo user.

Report each step's HTTP status and a one-line verdict. Do not modify any source
files or realm config.
