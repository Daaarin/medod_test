import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "./AuthContext";

export function ProtectedRoute({ adminOnly = false }) {
  const auth = useAuth();
  const location = useLocation();

  if (auth.loading) {
    return <div className="page-state">Загружаем сессию...</div>;
  }

  if (!auth.user) {
    return <Navigate to="/login" replace state={{ from: location }} />;
  }

  if (adminOnly && !auth.isAdmin) {
    return <div className="page-state">Доступ запрещен.</div>;
  }

  return <Outlet />;
}
