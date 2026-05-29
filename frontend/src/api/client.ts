import axios from "axios";

const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "";

export const apiClient = axios.create({
  baseURL: BASE_URL,
  headers: { "Content-Type": "application/json" },
});

// Attach Cognito access token to every request.
// oidc-client-ts stores the user under "oidc.user:<authority>:<client_id>",
// so we reconstruct the key from env vars rather than guessing "oidc.user".
apiClient.interceptors.request.use((config) => {
  const authority = import.meta.env.VITE_COGNITO_AUTHORITY ?? "";
  const clientId = import.meta.env.VITE_COGNITO_CLIENT_ID ?? "";

  if (authority && clientId) {
    const storageKey = `oidc.user:${authority}:${clientId}`;
    const raw = sessionStorage.getItem(storageKey);
    if (raw) {
      try {
        const user = JSON.parse(raw) as { access_token?: string };
        if (user.access_token) {
          config.headers.Authorization = `Bearer ${user.access_token}`;
        }
      } catch {
        // ignore parse errors
      }
    }
  }
  return config;
});
