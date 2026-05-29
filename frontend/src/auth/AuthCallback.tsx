import { useEffect } from "react";
import { useNavigate } from "react-router-dom";
import { useAuthContext } from "./AuthProvider";

export function AuthCallback() {
  const auth = useAuthContext();
  const navigate = useNavigate();

  useEffect(() => {
    if (!auth.isLoading && !auth.isAuthenticated) {
      navigate("/", { replace: true });
    } else if (auth.isAuthenticated) {
      navigate("/", { replace: true });
    }
  }, [auth.isAuthenticated, auth.isLoading, navigate]);

  return (
    <div className="flex items-center justify-center h-screen text-gray-500">
      Signing in…
    </div>
  );
}
