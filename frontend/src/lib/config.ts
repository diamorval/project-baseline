/** Runtime configuration, with localhost defaults for `docker compose up`. */
export const config = {
  keycloakUrl: import.meta.env.VITE_KEYCLOAK_URL ?? "http://localhost:8080",
  keycloakRealm: import.meta.env.VITE_KEYCLOAK_REALM ?? "hackathon",
  keycloakClientId: import.meta.env.VITE_KEYCLOAK_CLIENT_ID ?? "web",
  apiUrl: import.meta.env.VITE_API_URL ?? "http://localhost:8000",
};
