import React from "react";
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";

// Self-hosted Ufficio brand title font (registers the @font-face the DS title
// token prefers). Imported first so the face is ready when the DS CSS applies.
import "./fonts.css";
// The single Diametral stylesheet — tokens + reset + every component.
import "@diametral/design-system/css/diametral.css";
// Alternate themes for ConsoleLayout's Light/Dark/Sepia switcher. They're scoped
// to [data-theme="…"], so they stay inert until a theme is picked. Imported
// explicitly because this app pins the DS from npm (newer DS releases bundle them
// into diametral.css, making these lines redundant but harmless).
import "@diametral/design-system/css/themes/dark.css";
import "@diametral/design-system/css/themes/sepia.css";

import App from "./App";
import { keycloak } from "./lib/keycloak";

const root = createRoot(document.getElementById("root")!);

// Gate the whole app behind Keycloak: `login-required` redirects to the
// (Diametral-themed) Keycloak login page when there's no valid session.
keycloak
  .init({
    onLoad: "login-required",
    pkceMethod: "S256",
    checkLoginIframe: false,
  })
  .then((authenticated) => {
    if (!authenticated) {
      void keycloak.login();
      return;
    }
    root.render(
      <React.StrictMode>
        <BrowserRouter>
          <App />
        </BrowserRouter>
      </React.StrictMode>
    );
  })
  .catch(() => {
    root.render(
      <div style={{ padding: 40, fontFamily: "Geist, sans-serif" }}>
        <h1>Keycloak unavailable</h1>
        <p>
          Could not reach Keycloak at <code>{keycloak.authServerUrl}</code>. Make
          sure the stack is up (<code>docker compose up</code>) and try again.
        </p>
      </div>
    );
  });
