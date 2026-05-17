import { QueryClient, QueryClientProvider, useMutation, useQueryClient } from "@tanstack/react-query";
import { BrowserRouter, Navigate, Route, Routes, useNavigate } from "react-router-dom";
import { createApiClient } from "./api/client";
import { createEndpoints } from "./api/endpoints";
import { AdminPage } from "./admin/AdminPage";
import { AuthProvider } from "./auth/AuthContext";
import { LoginPage } from "./auth/LoginPage";
import { ProtectedRoute } from "./auth/ProtectedRoute";
import { getStoredToken, notifyUnauthorized } from "./auth/session";
import { Shell } from "./layout/Shell";
import { CalendarPage } from "./calendar/CalendarPage";
import { TaskDetail } from "./tasks/TaskDetail";
import { TaskForm } from "./tasks/TaskForm";
import { TaskListPage, TasksPage } from "./tasks/TaskList";
import { TagsPage } from "./tags/TagsPage";

const queryClient = new QueryClient();
const client = createApiClient({ getToken: getStoredToken, onUnauthorized: notifyUnauthorized });
const api = createEndpoints(client);

function PlaceholderPage({ title }) {
  return (
    <section className="panel">
      <p className="eyebrow">Скоро</p>
      <h2>{title}</h2>
    </section>
  );
}

function NewTaskPage({ api }) {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const createTask = useMutation({
    mutationFn: (task) => api.createTask(task),
    onSuccess: async (payload) => {
      await queryClient.invalidateQueries({ queryKey: ["tasks"] });
      const createdId = payload?.data?.id;
      if (createdId) {
        navigate(`/tasks/${createdId}`, { replace: true });
      }
    },
  });

  return (
    <section className="stack">
      <header className="page-header">
        <p className="eyebrow">Рабочая область</p>
        <h2>Новая задача</h2>
      </header>
      {createTask.isError ? (
        <div className="alert error">{createTask.error?.messages?.join(", ") || "Не удалось создать задачу"}</div>
      ) : null}
      <TaskForm onSubmit={(task) => createTask.mutate(task)} submitLabel="Создать задачу" />
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
                <Route path="/tasks/new" element={<NewTaskPage api={api} />} />
                <Route path="/tasks" element={<TasksPage api={api} title="Задачи" primaryAction={{ to: "/tasks/new", label: "Новая задача" }} />} />
                <Route
                  path="/delegated"
                  element={
                    <TaskListPage
                      api={api}
                      title="Делегированные задачи"
                      initialFilters={{ scope: "delegated_to_me", status: "pending_acceptance" }}
                      showScope={false}
                      hiddenFilters={["status"]}
                    />
                  }
                />
                <Route path="/tasks/:taskId" element={<TaskDetail api={api} />} />
                <Route path="/calendar" element={<CalendarPage api={api} />} />
                <Route path="/tags" element={<TagsPage api={api} />} />
                <Route element={<ProtectedRoute adminOnly />}>
                  <Route path="/admin" element={<AdminPage api={api} />} />
                </Route>
              </Route>
            </Route>
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </QueryClientProvider>
  );
}
