"""Application settings, loaded from environment variables.

Mirrors the recrutauto backend's split between an *internal* Keycloak URL
(server-to-server, used to fetch the JWKS signing keys over the Docker network)
and a *public* issuer URL (the host the browser uses, which is what ends up in
the token's `iss` claim). Keeping them separate is what makes JWT validation
work across the container boundary.
"""

from functools import cached_property

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # --- App database ---
    database_url: str = "postgresql+psycopg2://app:app@app-db:5432/app"

    # --- Keycloak ---
    # Reached from the backend container, over the compose network. Used for JWKS.
    keycloak_internal_url: str = "http://keycloak:8080"
    # Public base URL of Keycloak (what the browser uses) — must match the token
    # `iss` claim. Token issuer = f"{keycloak_issuer_url}/realms/{realm}".
    keycloak_issuer_url: str = "http://localhost:8080"
    keycloak_realm: str = "hackathon"
    keycloak_algorithm: str = "RS256"
    # Audience required in the token. The realm's `web` client has an audience
    # mapper that adds "hackathon-api" to every access token. Set to "" to
    # disable the audience check entirely.
    keycloak_audience: str = "hackathon-api"

    # --- CORS (comma-separated list of allowed origins) ---
    cors_origins: str = "http://localhost:5173"

    @cached_property
    def jwks_url(self) -> str:
        return (
            f"{self.keycloak_internal_url}/realms/{self.keycloak_realm}"
            "/protocol/openid-connect/certs"
        )

    @cached_property
    def issuer(self) -> str:
        return f"{self.keycloak_issuer_url}/realms/{self.keycloak_realm}"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


settings = Settings()
