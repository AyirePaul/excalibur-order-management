import "@testing-library/jest-dom";
import { vi } from "vitest";

// Mock oidc-client-ts so tests don't require a real Cognito pool
vi.mock("react-oidc-context", () => ({
  AuthProvider: ({ children }: { children: React.ReactNode }) => children,
  useAuth: () => ({
    isAuthenticated: true,
    isLoading: false,
    user: { profile: { email: "test@local", "cognito:groups": ["editor"] } },
    signinRedirect: vi.fn(),
    signoutRedirect: vi.fn(),
  }),
}));

// Suppress noisy React act() warnings in tests
const originalConsoleError = console.error;
console.error = (...args: unknown[]) => {
  if (typeof args[0] === "string" && args[0].includes("act(")) return;
  originalConsoleError(...args);
};
