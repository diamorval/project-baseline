import { useEffect, useState } from "react";
import {
  PageHeader,
  StatCard,
  Sparkline,
  Card,
  AreaChart,
  Status,
} from "@diametral/design-system/react";

import { api, ApiError } from "../lib/api";
import { keycloak } from "../lib/keycloak";
import type { Item } from "../lib/types";

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug"];
const REVENUE = [12, 19, 14, 23, 28, 26, 34, 41];
const SIGNUPS = [4, 6, 5, 9, 8, 12, 14, 18];

interface TokenProfile {
  name?: string;
  preferred_username?: string;
  email?: string;
}

export default function Dashboard() {
  const [items, setItems] = useState<Item[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api<Item[]>("/api/items")
      .then(setItems)
      .catch((e: ApiError) => setError(e.message));
  }, []);

  const profile = keycloak.tokenParsed as TokenProfile | undefined;
  const total = items?.length ?? 0;
  const done = items?.filter((i) => i.done).length ?? 0;

  return (
    <>
      <PageHeader
        title="Dashboard"
        subtitle="A Diametral-themed whiteapp on FastAPI + Keycloak + Postgres."
      />

      <Status
        status={error ? "danger" : "success"}
        kicker={error ? "Backend error" : "Authenticated"}
        heading={
          error
            ? "Could not reach the API"
            : `Signed in as ${profile?.name ?? profile?.preferred_username ?? "user"}`
        }
        subtitle={
          error
            ? error
            : `${profile?.email ?? ""} — your access token was validated by the FastAPI backend against Keycloak's signing keys.`
        }
      />

      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))",
          gap: "16px",
          margin: "24px 0",
        }}
      >
        <StatCard label="Your items" value={String(total)} />
        <StatCard label="Completed" value={String(done)} />
        <StatCard label="Revenue" value="€41k" delta="+18%" deltaDir="up">
          <Sparkline data={REVENUE} fill />
        </StatCard>
        <StatCard label="Sign-ups" value="1,284" delta="+9%" deltaDir="up">
          <Sparkline data={SIGNUPS} fill />
        </StatCard>
      </div>

      <Card title="Revenue vs. sign-ups">
        <AreaChart
          width={760}
          height={240}
          labels={MONTHS}
          series={[
            { name: "Revenue", data: REVENUE },
            { name: "Sign-ups", data: SIGNUPS },
          ]}
          style={{ width: "100%" }}
        />
      </Card>
    </>
  );
}
