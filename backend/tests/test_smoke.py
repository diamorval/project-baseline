"""Smoke tests — the minimal "is the app wired up?" checks.

Deliberately need no database: TestClient is NOT used as a context manager, so
the lifespan (which runs `create_all`) never fires. They exercise only the
health endpoint and the auth gate, both of which are DB-free. This is the seed
test suite — add real unit/integration tests as the app grows.
"""

from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_health_ok():
    """The unauthenticated health endpoint returns 200 + status ok."""
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_me_requires_auth():
    """A protected route returns 403 when called without a bearer token."""
    resp = client.get("/api/me")
    assert resp.status_code == 403


def test_app_metadata():
    """The app object is constructed with the expected identity."""
    assert app.title == "Baseline API"
