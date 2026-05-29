import type { ReactNode } from "react";
import { useAuth } from "./useAuth";

interface Props {
  children: ReactNode;
  requireEditor?: boolean;
}

export function ProtectedRoute({ children, requireEditor = false }: Props) {
  const { isAuthenticated, isLoading, login, isEditor } = useAuth();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center h-48 text-gray-500">
        Authenticating…
      </div>
    );
  }

  if (!isAuthenticated) {
    return (
      <div className="flex flex-col items-center justify-center h-48 gap-4">
        <p className="text-gray-600">Please sign in to continue.</p>
        <button
          onClick={login}
          className="px-4 py-2 bg-brand-600 text-white rounded hover:bg-brand-700 transition-colors"
        >
          Sign in
        </button>
      </div>
    );
  }

  if (requireEditor && !isEditor) {
    return (
      <div className="flex items-center justify-center h-48 text-red-600">
        You need the <strong className="mx-1">editor</strong> role to access this page.
      </div>
    );
  }

  return <>{children}</>;
}
