import Keycloak from "keycloak-js";

import { config } from "./config";

/** Single shared Keycloak client for the app. */
export const keycloak = new Keycloak({
  url: config.keycloakUrl,
  realm: config.keycloakRealm,
  clientId: config.keycloakClientId,
});
