import { config } from "./config";
import { keycloak } from "./keycloak";

/** Thrown for any non-2xx response; carries the HTTP status. */
export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
    this.name = "ApiError";
  }
}

/**
 * `fetch` wrapper that attaches a fresh Keycloak bearer token and parses JSON.
 * Refreshes the token if it expires within 30s; if that fails, sends the user
 * back to the login page.
 */
export async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
  try {
    await keycloak.updateToken(30);
  } catch {
    await keycloak.login();
    throw new ApiError(401, "Session expired");
  }

  const res = await fetch(`${config.apiUrl}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(options.headers ?? {}),
      Authorization: `Bearer ${keycloak.token}`,
    },
  });

  if (!res.ok) {
    const body = await res.text();
    throw new ApiError(res.status, body || `${res.status} ${res.statusText}`);
  }

  // 204 No Content (e.g. DELETE) has no body to parse.
  return res.status === 204 ? (undefined as T) : ((await res.json()) as T);
}
