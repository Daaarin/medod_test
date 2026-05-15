import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { createApiClient } from "./api/client";
import { createEndpoints } from "./api/endpoints";
import { AuthProvider } from "./auth/AuthContext";
import { LoginPage } from "./auth/LoginPage";
import { ProtectedRoute } from "./auth/ProtectedRoute";
import { getStoredToken, notifyUnauthorized } from "./auth/session";
import { Shell } from "./layout/Shell";
import { CalendarPage } from "./calendar/CalendarPage";
import { TaskListPage, TasksPage } from "./tasks/TaskList";

const queryClient = new QueryClient();
const client = createApiClient({ getToken: getStoredToken, onUnauthorized: notifyUnauthorized });
const api = createEndpoints(client);

function PlaceholderPage({ title }) {
  return (
    <section className="panel">
      <p className="eyebrow">Coming soon</p>
      <h2>{title}</h2>
    </section>
  );
}

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
                <Route
                  path="/delegated"
                  element={
                    <TaskListPage
                      api={api}
                      title="Delegated"
                      initialFilters={{ scope: "delegated_to_me", status: "pending_acceptance" }}
                    />
                  }
                />
                <Route path="/calendar" element={<CalendarPage api={api} />} />
                <Route path="/tags" element={<PlaceholderPage title="Tags" />} />
                <Route element={<ProtectedRoute adminOnly />}>
                  <Route path="/admin" element={<PlaceholderPage title="Admin" />} />
                </Route>
              </Route>
            </Route>
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </QueryClientProvider>
  );
}
