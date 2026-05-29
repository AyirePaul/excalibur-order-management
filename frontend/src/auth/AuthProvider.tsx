import { createContext, useContext } from "react";
import { AuthProvider as OidcAuthProvider, useAuth as useOidcAuth } from "react-oidc-context";
import type { ReactNode } from "react";

// ── Shared auth shape ─────────────────────────────────────────────────────────

export interface AuthValue {
  isAuthenticated: boolean;
  isLoading: boolean;
  isEditor: boolean;
  isViewer: boolean;
  user: { profile?: Record<string, unknown> } | null | undefined;
  login: () => Promise<void>;
  logout: () => Promise<void>;
}

const LOCAL_DEV_AUTH: AuthValue = {
  isAuthenticated: true,
  isLoading: false,
  isEditor: true,
  isViewer: true,
  user: { profile: { email: "dev@local", "cognito:groups": ["editor"] } },
  login: () => Promise.resolve(),
  logout: () => Promise.resolve(),
};

export const AuthContext = createContext<AuthValue>(LOCAL_DEV_AUTH);

// ── OidcBridge: translates react-oidc-context state into AuthContext ──────────
// This component is ONLY rendered when OidcAuthProvider is present, so
// useOidcAuth() is always called unconditionally — no rules-of-hooks violation.

function OidcBridge({ children }: { children: ReactNode }) {
  const auth = useOidcAuth();
  const groups: string[] = Array.isArray(auth.user?.profile?.["cognito:groups"])
    ? (auth.user!.profile!["cognito:groups"] as string[])
    : [];

  const value: AuthValue = {
    isAuthenticated: auth.isAuthenticated,
    isLoading: auth.isLoading,
    isEditor: groups.includes("editor"),
    isViewer: groups.includes("viewer") || groups.includes("editor"),
    user: auth.user,
    login: () => auth.signinRedirect(),
    logout: () => auth.signoutRedirect(),
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// ── AuthProvider ──────────────────────────────────────────────────────────────

const cognitoAuthority = import.meta.env.VITE_COGNITO_AUTHORITY ?? "";
const clientId = import.meta.env.VITE_COGNITO_CLIENT_ID ?? "";
const redirectUri =
  import.meta.env.VITE_COGNITO_REDIRECT_URI ?? "http://localhost:5173/auth/callback";

export function AuthProvider({ children }: { children: ReactNode }) {
  if (!cognitoAuthority || !clientId) {
    // Local dev: serve the mock auth value directly — no OIDC provider needed
    return (
      <AuthContext.Provider value={LOCAL_DEV_AUTH}>{children}</AuthContext.Provider>
    );
  }

  return (
    <OidcAuthProvider
      authority={cognitoAuthority}
      client_id={clientId}
      redirect_uri={redirectUri}
      scope="openid email profile"
      automaticSilentRenew
    >
      <OidcBridge>{children}</OidcBridge>
    </OidcAuthProvider>
  );
}

export function useAuthContext(): AuthValue {
  return useContext(AuthContext);
}
