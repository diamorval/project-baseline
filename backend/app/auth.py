"""Keycloak JWT authentication for FastAPI.

Validates the bearer access token sent by the frontend against the realm's
public signing keys (JWKS), checking the signature, issuer, expiry and (by
default) audience. Modeled on the recrutauto backend, minus the Redis cache —
here the JWKS itself is cached in-process for 5 minutes.
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field

import httpx
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from .config import settings

bearer_scheme = HTTPBearer(auto_error=True)


@dataclass
class CurrentUser:
    """The authenticated principal, distilled from the token claims."""

    sub: str
    username: str | None = None
    email: str | None = None
    first_name: str | None = None
    last_name: str | None = None
    roles: list[str] = field(default_factory=list)

    @property
    def display_name(self) -> str:
        full = " ".join(filter(None, [self.first_name, self.last_name]))
        return full or self.username or self.email or self.sub

    def has_role(self, role: str) -> bool:
        return role in self.roles


# --- JWKS cache -------------------------------------------------------------
# The realm's signing keys rarely change; cache them and only re-fetch when the
# TTL lapses or a token references a key id we haven't seen (key rotation).
_jwks: dict[str, object] = {"keys": [], "fetched_at": 0.0}
_JWKS_TTL_SECONDS = 300


def _fetch_jwks() -> list[dict]:
    resp = httpx.get(settings.jwks_url, timeout=5.0)
    resp.raise_for_status()
    return resp.json().get("keys", [])


def _get_jwks(force: bool = False) -> list[dict]:
    now = time.time()
    stale = now - float(_jwks["fetched_at"]) > _JWKS_TTL_SECONDS
    if force or not _jwks["keys"] or stale:
        try:
            _jwks["keys"] = _fetch_jwks()
            _jwks["fetched_at"] = now
        except httpx.HTTPError as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Unable to reach Keycloak to verify the token.",
            ) from exc
    return _jwks["keys"]  # type: ignore[return-value]


def _signing_key(token: str) -> dict:
    try:
        kid = jwt.get_unverified_header(token).get("kid")
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Malformed token header."
        ) from exc

    def find(keys: list[dict]) -> dict | None:
        return next((k for k in keys if k.get("kid") == kid), None)

    key = find(_get_jwks())
    if key is None:  # unknown kid — keys may have rotated, refresh once
        key = find(_get_jwks(force=True))
    if key is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unknown signing key.")
    return key


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> CurrentUser:
    """FastAPI dependency that decodes + validates the Keycloak access token."""
    token = creds.credentials
    key = _signing_key(token)
    try:
        payload = jwt.decode(
            token,
            key,
            algorithms=[settings.keycloak_algorithm],
            issuer=settings.issuer,
            audience=settings.keycloak_audience or None,
            options={"verify_aud": bool(settings.keycloak_audience)},
        )
    except JWTError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {exc}",
        ) from exc

    return CurrentUser(
        sub=payload["sub"],
        username=payload.get("preferred_username"),
        email=payload.get("email"),
        first_name=payload.get("given_name"),
        last_name=payload.get("family_name"),
        roles=payload.get("realm_access", {}).get("roles", []),
    )


def require_role(role: str):
    """Dependency factory: 403 unless the user has the given realm role."""

    def checker(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if not user.has_role(role):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Requires role: {role}",
            )
        return user

    return checker
