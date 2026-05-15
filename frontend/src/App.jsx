import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { createApiClient } from "./api/client";
import { createEndpoints } from "./api/endpoints";
import { AuthProvider } from "./auth/AuthContext";
import { LoginPage } from "./auth/LoginPage";
import { ProtectedRoute } from "./auth/ProtectedRoute";
import { getStoredToken } from "./auth/session";
import { Shell } from "./layout/Shell";
import { TasksPage } from "./tasks/TaskList";

const queryClient = new QueryClient();
const client = createApiClient({ getToken: getStoredToken });
const api = createEndpoints(client);

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider api={api}>
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route element={<ProtectedRoute />}>
              <Route element={<Shell />}>
                <Route index element={<Navigate to="/tasks" replace />} />
                <Route path="/tasks" element={<TasksPage api={api} />} />
              </Route>
            </Route>
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </QueryClientProvider>
  );
}
