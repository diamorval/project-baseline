import { Routes, Route, useNavigate, useLocation } from "react-router-dom";
import {
  ConsoleLayout,
  Badge,
  type ConsoleNavGroup,
} from "@diametral/design-system/react";

import { keycloak } from "./lib/keycloak";
import Dashboard from "./pages/Dashboard";
import Items from "./pages/Items";

/* ---------------------------------------------------------------------------
   Navigation model — one source of truth. Each entry has the ConsoleLayout nav
   `id` plus the route `path` it maps to. Add a page = add a line here + a
   <Route> below.
   --------------------------------------------------------------------------- */
type NavEntry = { id: string; path: string };

const ROUTES: NavEntry[] = [
  { id: "dashboard", path: "/" },
  { id: "items", path: "/items" },
];

const NAV: ConsoleNavGroup[] = [
  { group: "Overview", items: [{ id: "dashboard", label: "Dashboard" }] },
  { group: "Manage", items: [{ id: "items", label: "Items" }] },
];

/** Pick the nav id whose path best matches the current location. */
function activeId(pathname: string): string {
  const match = [...ROUTES]
    .sort((a, b) => b.path.length - a.path.length)
    .find((r) =>
      r.path === "/" ? pathname === "/" : pathname.startsWith(r.path)
    );
  return match?.id ?? "dashboard";
}

/** Build avatar initials from a display name or username. */
function initialsOf(name: string | undefined): string {
  const src = (name ?? "?").trim();
  const parts = src.split(/\s+/).filter(Boolean);
  const raw =
    parts.length > 1 ? parts[0][0] + parts[parts.length - 1][0] : src.slice(0, 2);
  return raw.toUpperCase();
}

interface TokenProfile {
  name?: string;
  preferred_username?: string;
}

export default function App() {
  const navigate = useNavigate();
  const { pathname } = useLocation();

  const profile = keycloak.tokenParsed as TokenProfile | undefined;
  const displayName = profile?.name ?? profile?.preferred_username ?? "User";

  const onNavigate = (id: string) => {
    const entry = ROUTES.find((r) => r.id === id);
    if (entry) navigate(entry.path);
  };

  return (
    <ConsoleLayout
      brand={{ name: "Baseline", sub: "Starter" }}
      nav={NAV}
      active={activeId(pathname)}
      onNavigate={onNavigate}
      themes
      searchPlaceholder="Search…"
      user={{
        initials: initialsOf(displayName),
        name: displayName,
        onSignOut: () =>
          keycloak.logout({ redirectUri: window.location.origin }),
      }}
      actions={<Badge variant="accent">Diametral</Badge>}
    >
      <Routes>
        <Route path="/" element={<Dashboard />} />
        <Route path="/items" element={<Items />} />
        <Route path="*" element={<Dashboard />} />
      </Routes>
    </ConsoleLayout>
  );
}
