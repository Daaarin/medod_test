# Frontend Backend Feature Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade the React/Vite frontend into a hybrid staff operations app that uses the new authenticated task, delegation, tag, recurrence, occurrence, and admin-support backend features.

**Architecture:** Keep one React app and add role-aware routing on top of a shared task workspace. Centralize API/session behavior in small modules, keep React Query as the cache layer, and split task, recurrence, tags, calendar, admin, and auth UI into focused feature folders.

**Tech Stack:** React 18, React Router 6, TanStack React Query 5, Vite 5, Rails JSON API, Vitest, React Testing Library, jsdom.

---

## File Structure

Create or modify these files:
- Modify `frontend/package.json` - add test scripts and frontend test dependencies.
- Modify `frontend/vite.config.js` - add Vitest configuration.
- Create `frontend/src/test/setup.js` - testing-library setup.
- Create `frontend/src/api/client.js` - API base URL, bearer token handling, JSON parsing, error normalization.
- Create `frontend/src/api/endpoints.js` - task, auth, tag, occurrence endpoint wrappers.
- Create `frontend/src/auth/session.js` - local storage token helpers.
- Create `frontend/src/auth/AuthContext.jsx` - session provider, login/logout, current user loading.
- Create `frontend/src/auth/LoginPage.jsx` - login form.
- Create `frontend/src/auth/ProtectedRoute.jsx` - authenticated and role-protected route wrappers.
- Create `frontend/src/layout/Shell.jsx` - role-aware app shell and navigation.
- Create `frontend/src/tasks/taskConstants.js` - lifecycle, scope, occurrence, task kind, and recurrence constants.
- Create `frontend/src/tasks/TaskFilters.jsx` - task list filters.
- Create `frontend/src/tasks/TaskList.jsx` - shared task list and row rendering.
- Create `frontend/src/tasks/TaskDetail.jsx` - detail view, edit/deactivate, delegation, tags, occurrence actions.
- Create `frontend/src/tasks/TaskForm.jsx` - one-time and recurring task creation form.
- Create `frontend/src/recurrence/RecurrenceFields.jsx` - recurrence-mode-specific form fields.
- Create `frontend/src/tags/TagsPage.jsx` - tag catalog and maintenance UI.
- Create `frontend/src/calendar/CalendarPage.jsx` - date-window occurrence projection view.
- Create `frontend/src/admin/AdminPage.jsx` - health, Swagger, admin presets, deactivated tag maintenance.
- Modify `frontend/src/App.jsx` - replace placeholder routes with protected role-aware routes.
- Modify `frontend/src/styles.css` - replace placeholder styling with dense operational UI styling.
- Create tests beside the modules as `*.test.jsx` or `*.test.js`.
- Modify `HISTORY.md` - record the completed implementation planning step.

The implementation should not add backend routes. Where the backend lacks users list or attached tag state in task payloads, the frontend must use numeric user ids and conditional tag display.

---

### Task 1: Test Harness And API Client

**Files:**
- Modify: `frontend/package.json`
- Modify: `frontend/vite.config.js`
- Create: `frontend/src/test/setup.js`
- Create: `frontend/src/api/client.js`
- Create: `frontend/src/api/client.test.js`
- Create: `frontend/src/api/endpoints.js`

- [ ] **Step 1: Install frontend test dependencies**

Run:

```bash
cd frontend
npm install --save-dev vitest jsdom @testing-library/react @testing-library/jest-dom @testing-library/user-event
```

Expected: `package.json` is updated with the new dev dependencies and a lockfile is created if npm generates one.

- [ ] **Step 2: Add test scripts**

Update `frontend/package.json` scripts:

```json
{
  "scripts": {
    "build": "vite build",
    "dev": "vite",
    "preview": "vite preview --host 0.0.0.0 --port 4173",
    "test": "vitest run",
    "test:watch": "vitest"
  }
}
```

- [ ] **Step 3: Configure Vitest**

Update `frontend/vite.config.js`:

```js
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    host: "0.0.0.0",
    port: 5173,
  },
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: "./src/test/setup.js",
  },
});
```

- [ ] **Step 4: Add test setup**

Create `frontend/src/test/setup.js`:

```js
import "@testing-library/jest-dom/vitest";
```

- [ ] **Step 5: Write failing API client tests**

Create `frontend/src/api/client.test.js`:

```js
import { afterEach, describe, expect, it, vi } from "vitest";
import { ApiError, createApiClient } from "./client";

describe("createApiClient", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("attaches bearer tokens and parses JSON responses", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      headers: new Headers({ "content-type": "application/json" }),
      json: async () => ({ data: { id: "1" } }),
    });

    const client = createApiClient({
      baseUrl: "http://api.test",
      getToken: () => "token-123",
      fetchImpl: fetchMock,
    });

    await expect(client.request("/api/v1/tasks")).resolves.toEqual({ data: { id: "1" } });
    expect(fetchMock).toHaveBeenCalledWith(
      "http://api.test/api/v1/tasks",
      expect.objectContaining({
        headers: expect.objectContaining({ Authorization: "Bearer token-123" }),
      }),
    );
  });

  it("normalizes single error responses", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: false,
      status: 400,
      headers: new Headers({ "content-type": "application/json" }),
      json: async () => ({ error: "status is not included in the list" }),
    });

    const client = createApiClient({ baseUrl: "http://api.test", fetchImpl: fetchMock });

    await expect(client.request("/api/v1/tasks?status=bad")).rejects.toMatchObject({
      status: 400,
      messages: ["status is not included in the list"],
    });
  });

  it("normalizes array error responses", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: false,
      status: 422,
      headers: new Headers({ "content-type": "application/json" }),
      json: async () => ({ errors: ["Name can't be blank"] }),
    });

    const client = createApiClient({ baseUrl: "http://api.test", fetchImpl: fetchMock });

    await expect(client.request("/api/v1/tasks", { method: "POST" })).rejects.toBeInstanceOf(ApiError);
  });
});
```

- [ ] **Step 6: Run tests and verify failure**

Run:

```bash
cd frontend
npm test -- src/api/client.test.js
```

Expected: FAIL because `frontend/src/api/client.js` does not exist yet.

- [ ] **Step 7: Implement API client and endpoint wrappers**

Create `frontend/src/api/client.js`:

```js
export class ApiError extends Error {
  constructor({ status, messages, payload }) {
    super(messages.join(", "));
    this.name = "ApiError";
    this.status = status;
    this.messages = messages;
    this.payload = payload;
  }
}

export const apiBase = import.meta.env.VITE_API_BASE_URL || "http://localhost:3000";

function hasJsonContent(response) {
  return response.headers.get("content-type")?.includes("application/json");
}

async function parsePayload(response) {
  if (response.status === 204) return null;
  if (!hasJsonContent(response)) return response.text();
  return response.json();
}

function errorMessages(payload, fallback) {
  if (Array.isArray(payload?.errors)) return payload.errors;
  if (payload?.error) return [payload.error];
  if (typeof payload === "string" && payload.trim()) return [payload];
  return [fallback];
}

export function createApiClient({ baseUrl = apiBase, getToken, onUnauthorized, fetchImpl = fetch } = {}) {
  async function request(path, options = {}) {
    const token = getToken?.();
    const headers = {
      Accept: "application/json",
      ...(options.body ? { "Content-Type": "application/json" } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    };

    const response = await fetchImpl(`${baseUrl}${path}`, { ...options, headers });
    const payload = await parsePayload(response);

    if (!response.ok) {
      if (response.status === 401) onUnauthorized?.();
      throw new ApiError({
        status: response.status,
        payload,
        messages: errorMessages(payload, `Request failed with ${response.status}`),
      });
    }

    return payload;
  }

  return { request };
}
```

Create `frontend/src/api/endpoints.js`:

```js
function queryString(params = {}) {
  const search = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== "") search.set(key, value);
  });
  const value = search.toString();
  return value ? `?${value}` : "";
}

function jsonBody(body) {
  return JSON.stringify(body);
}

export function createEndpoints(client) {
  return {
    login: (credentials) =>
      client.request("/api/v1/auth/login", {
        method: "POST",
        body: jsonBody(credentials),
      }),
    me: () => client.request("/api/v1/auth/me"),
    health: () => client.request("/up"),
    tasks: (params) => client.request(`/api/v1/tasks${queryString(params)}`),
    task: (id) => client.request(`/api/v1/tasks/${id}`),
    createTask: (task) =>
      client.request("/api/v1/tasks", {
        method: "POST",
        body: jsonBody({ task }),
      }),
    updateTask: (id, task) =>
      client.request(`/api/v1/tasks/${id}`, {
        method: "PATCH",
        body: jsonBody({ task }),
      }),
    deactivateTask: (id) => client.request(`/api/v1/tasks/${id}`, { method: "DELETE" }),
    acceptTask: (taskId) => client.request(`/api/v1/tasks/${taskId}/accept`, { method: "POST" }),
    declineTask: (taskId) => client.request(`/api/v1/tasks/${taskId}/decline`, { method: "POST" }),
    tags: (params) => client.request(`/api/v1/tags${queryString(params)}`),
    createTag: (tag) =>
      client.request("/api/v1/tags", {
        method: "POST",
        body: jsonBody({ tag }),
      }),
    updateTag: (id, tag) =>
      client.request(`/api/v1/tags/${id}`, {
        method: "PATCH",
        body: jsonBody({ tag }),
      }),
    deactivateTag: (id) => client.request(`/api/v1/tags/${id}`, { method: "DELETE" }),
    attachTag: (taskId, tagId) => client.request(`/api/v1/tasks/${taskId}/tags/${tagId}`, { method: "POST" }),
    detachTag: (taskId, tagId) => client.request(`/api/v1/tasks/${taskId}/tags/${tagId}`, { method: "DELETE" }),
    postponeOccurrence: (id, postponedTo) =>
      client.request(`/api/v1/task_occurrences/${id}/postpone`, {
        method: "POST",
        body: jsonBody({ postponed_to: postponedTo }),
      }),
    executeOccurrence: (id) => client.request(`/api/v1/task_occurrences/${id}/execute`, { method: "POST" }),
    skipOccurrence: (id, skipReason) =>
      client.request(`/api/v1/task_occurrences/${id}/skip`, {
        method: "POST",
        body: jsonBody({ skip_reason: skipReason }),
      }),
  };
}
```

- [ ] **Step 8: Run tests and build**

Run:

```bash
cd frontend
npm test -- src/api/client.test.js
npm run build
```

Expected: tests PASS and Vite build succeeds.

- [ ] **Step 9: Commit**

```bash
git add frontend/package.json frontend/package-lock.json frontend/vite.config.js frontend/src/test/setup.js frontend/src/api
git commit -m "Add frontend API client test harness"
```

---

### Task 2: Auth Session And Protected Routing

**Files:**
- Create: `frontend/src/auth/session.js`
- Create: `frontend/src/auth/AuthContext.jsx`
- Create: `frontend/src/auth/LoginPage.jsx`
- Create: `frontend/src/auth/ProtectedRoute.jsx`
- Create: `frontend/src/auth/AuthContext.test.jsx`
- Modify: `frontend/src/App.jsx`

- [ ] **Step 1: Write auth provider tests**

Create `frontend/src/auth/AuthContext.test.jsx`:

```jsx
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { AuthProvider, useAuth } from "./AuthContext";

function Probe() {
  const auth = useAuth();
  return (
    <div>
      <span>{auth.user?.email || "anonymous"}</span>
      <button onClick={() => auth.login({ email: "admin@example.test", password: "secret" })}>login</button>
      <button onClick={auth.logout}>logout</button>
    </div>
  );
}

function renderAuth(api) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return render(
    <QueryClientProvider client={queryClient}>
      <AuthProvider api={api}>
        <Probe />
      </AuthProvider>
    </QueryClientProvider>,
  );
}

describe("AuthProvider", () => {
  it("logs in and exposes the current user", async () => {
    const api = {
      login: vi.fn().mockResolvedValue({
        token: "token-1",
        user: { id: 1, email: "admin@example.test", role: "administrator" },
      }),
      me: vi.fn(),
    };

    renderAuth(api);
    await userEvent.click(screen.getByRole("button", { name: "login" }));

    await waitFor(() => expect(screen.getByText("admin@example.test")).toBeInTheDocument());
    expect(window.localStorage.getItem("medods.authToken")).toBe("token-1");
  });
});
```

- [ ] **Step 2: Run auth test and verify failure**

Run:

```bash
cd frontend
npm test -- src/auth/AuthContext.test.jsx
```

Expected: FAIL because auth modules do not exist yet.

- [ ] **Step 3: Implement token storage**

Create `frontend/src/auth/session.js`:

```js
const TOKEN_KEY = "medods.authToken";

export function getStoredToken() {
  return window.localStorage.getItem(TOKEN_KEY);
}

export function storeToken(token) {
  window.localStorage.setItem(TOKEN_KEY, token);
}

export function clearStoredToken() {
  window.localStorage.removeItem(TOKEN_KEY);
}
```

- [ ] **Step 4: Implement auth context**

Create `frontend/src/auth/AuthContext.jsx`:

```jsx
import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { clearStoredToken, getStoredToken, storeToken } from "./session";

const AuthContext = createContext(null);

export function AuthProvider({ api, children }) {
  const [token, setToken] = useState(() => getStoredToken());
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(Boolean(token));
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);
    api
      .me()
      .then((payload) => {
        if (!cancelled) setUser(payload.user);
      })
      .catch(() => {
        if (!cancelled) {
          clearStoredToken();
          setToken(null);
          setUser(null);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });

    return () => {
      cancelled = true;
    };
  }, [api, token]);

  async function login(credentials) {
    setError(null);
    const payload = await api.login(credentials);
    storeToken(payload.token);
    setToken(payload.token);
    setUser(payload.user);
    return payload.user;
  }

  function logout() {
    clearStoredToken();
    setToken(null);
    setUser(null);
  }

  const value = useMemo(
    () => ({ token, user, loading, error, setError, login, logout, isAdmin: user?.role === "administrator" }),
    [token, user, loading, error],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) throw new Error("useAuth must be used inside AuthProvider");
  return value;
}
```

- [ ] **Step 5: Implement login page and route guards**

Create `frontend/src/auth/LoginPage.jsx`:

```jsx
import { useState } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "./AuthContext";

export function LoginPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  if (auth.user) return <Navigate to="/" replace />;

  async function onSubmit(event) {
    event.preventDefault();
    setError("");
    try {
      await auth.login({ email, password });
      navigate(location.state?.from?.pathname || "/", { replace: true });
    } catch (requestError) {
      setError(requestError.messages?.join(", ") || "Unable to sign in");
    }
  }

  return (
    <main className="login-page">
      <form className="auth-card" onSubmit={onSubmit}>
        <p className="eyebrow">Medods Tasks</p>
        <h1>Sign in</h1>
        {error ? <div className="alert error">{error}</div> : null}
        <label>
          Email
          <input type="email" value={email} onChange={(event) => setEmail(event.target.value)} required />
        </label>
        <label>
          Password
          <input type="password" value={password} onChange={(event) => setPassword(event.target.value)} required />
        </label>
        <button type="submit">Sign in</button>
      </form>
    </main>
  );
}
```

Create `frontend/src/auth/ProtectedRoute.jsx`:

```jsx
import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "./AuthContext";

export function ProtectedRoute({ adminOnly = false }) {
  const auth = useAuth();
  const location = useLocation();

  if (auth.loading) return <div className="page-state">Loading session...</div>;
  if (!auth.user) return <Navigate to="/login" replace state={{ from: location }} />;
  if (adminOnly && !auth.isAdmin) return <div className="page-state">Access denied.</div>;

  return <Outlet />;
}
```

- [ ] **Step 6: Wire auth into App**

Modify `frontend/src/App.jsx` to create the API client and wrap routes:

```jsx
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
```

This temporary route points at `TasksPage`, which Task 4 will create.

- [ ] **Step 7: Run tests and build**

Run:

```bash
cd frontend
npm test -- src/auth/AuthContext.test.jsx
npm run build
```

Expected: auth test PASS. Build may fail until `Shell` and `TasksPage` exist; if so, create temporary exports in Task 3 before committing.

- [ ] **Step 8: Commit**

```bash
git add frontend/src/auth frontend/src/App.jsx
git commit -m "Add frontend authentication session"
```

---

### Task 3: Role-Aware Layout And Navigation

**Files:**
- Create: `frontend/src/layout/Shell.jsx`
- Create: `frontend/src/layout/Shell.test.jsx`
- Modify: `frontend/src/styles.css`

- [ ] **Step 1: Write layout navigation test**

Create `frontend/src/layout/Shell.test.jsx`:

```jsx
import { render, screen } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { describe, expect, it } from "vitest";
import { AuthProvider } from "../auth/AuthContext";
import { Shell } from "./Shell";

function renderShell(user) {
  const api = { me: async () => ({ user }) };
  window.localStorage.setItem("medods.authToken", "token");
  render(
    <AuthProvider api={api}>
      <MemoryRouter initialEntries={["/tasks"]}>
        <Routes>
          <Route element={<Shell />}>
            <Route path="/tasks" element={<div>Tasks content</div>} />
          </Route>
        </Routes>
      </MemoryRouter>
    </AuthProvider>,
  );
}

describe("Shell", () => {
  it("hides admin navigation for staff users", async () => {
    renderShell({ id: 2, email: "nurse@example.test", role: "nurse", name: "Nina", last_name: "Nurse" });
    expect(await screen.findByText("Tasks content")).toBeInTheDocument();
    expect(screen.queryByRole("link", { name: "Admin" })).not.toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run layout test and verify failure**

Run:

```bash
cd frontend
npm test -- src/layout/Shell.test.jsx
```

Expected: FAIL because `Shell.jsx` does not exist.

- [ ] **Step 3: Implement shell**

Create `frontend/src/layout/Shell.jsx`:

```jsx
import { NavLink, Outlet } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";

const baseLinks = [
  { to: "/tasks", label: "Tasks" },
  { to: "/delegated", label: "Delegated" },
  { to: "/calendar", label: "Calendar" },
  { to: "/tags", label: "Tags" },
];

export function Shell() {
  const auth = useAuth();
  const links = auth.isAdmin ? [...baseLinks, { to: "/admin", label: "Admin" }] : baseLinks;
  const displayName = [auth.user?.name, auth.user?.last_name].filter(Boolean).join(" ") || auth.user?.email;

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div>
          <p className="eyebrow">Medods Tasks</p>
          <h1>Operations</h1>
          <p className="sidebar-copy">{displayName}</p>
          <p className="role-label">{auth.user?.role}</p>
        </div>
        <nav className="tabs" aria-label="Primary">
          {links.map((link) => (
            <NavLink key={link.to} to={link.to}>
              {link.label}
            </NavLink>
          ))}
        </nav>
        <button type="button" className="secondary-button" onClick={auth.logout}>
          Sign out
        </button>
      </aside>
      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
```

- [ ] **Step 4: Replace global styles**

Modify `frontend/src/styles.css` to support the operational layout:

```css
:root {
  color-scheme: light;
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  background: #f5f7fb;
  color: #172033;
  line-height: 1.5;
}

* { box-sizing: border-box; }
html, body, #root { margin: 0; min-height: 100%; }
body { min-height: 100vh; }
a { color: inherit; text-decoration: none; }
button, input, select, textarea { font: inherit; }

.app-shell {
  display: grid;
  grid-template-columns: 280px 1fr;
  min-height: 100vh;
}

.sidebar {
  background: #101828;
  color: #f8fafc;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
  padding: 1.5rem;
}

.content {
  padding: 1.5rem;
}

.eyebrow {
  color: #7dd3fc;
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0;
  margin: 0 0 0.5rem;
  text-transform: uppercase;
}

h1, h2, h3, p { margin-top: 0; }
h1 { font-size: 1.75rem; line-height: 1.1; }
h2 { font-size: 1.5rem; }

.sidebar-copy, .role-label { color: #cbd5e1; margin-bottom: 0.5rem; }
.role-label { text-transform: capitalize; }

.tabs {
  display: grid;
  gap: 0.5rem;
}

.tabs a, .secondary-button, button {
  border: 1px solid #d0d5dd;
  border-radius: 0.5rem;
  cursor: pointer;
  padding: 0.7rem 0.9rem;
}

.tabs a {
  border-color: rgba(255, 255, 255, 0.14);
  color: #e2e8f0;
}

.tabs a.active {
  background: #f8fafc;
  color: #101828;
}

.secondary-button {
  background: transparent;
  color: #f8fafc;
}

.page-header, .toolbar, .panel, .table-card, .auth-card {
  background: #ffffff;
  border: 1px solid #e4e7ec;
  border-radius: 0.5rem;
  padding: 1rem;
}

.stack { display: grid; gap: 1rem; }
.toolbar { display: flex; flex-wrap: wrap; gap: 0.75rem; align-items: end; }
.form-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 0.75rem; }
label { display: grid; gap: 0.35rem; font-weight: 600; }
input, select, textarea { border: 1px solid #d0d5dd; border-radius: 0.5rem; padding: 0.65rem; }
textarea { min-height: 90px; resize: vertical; }
button { background: #155eef; color: #ffffff; }
button[disabled] { background: #98a2b3; cursor: not-allowed; }
.alert.error { background: #fef3f2; border: 1px solid #fecdca; border-radius: 0.5rem; color: #b42318; padding: 0.75rem; }
.page-state { padding: 2rem; }
.login-page { display: grid; min-height: 100vh; place-items: center; padding: 1rem; }
.auth-card { width: min(420px, 100%); }

@media (max-width: 860px) {
  .app-shell { grid-template-columns: 1fr; }
  .sidebar { position: static; }
}
```

- [ ] **Step 5: Run layout tests and build**

Run:

```bash
cd frontend
npm test -- src/layout/Shell.test.jsx
npm run build
```

Expected: test PASS and build succeeds after Task 4 creates `TasksPage`, or with a temporary stub if Task 4 has not been started.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/layout frontend/src/styles.css
git commit -m "Add role-aware frontend shell"
```

---

### Task 4: Task List, Filters, And Calendar Projection

**Files:**
- Create: `frontend/src/tasks/taskConstants.js`
- Create: `frontend/src/tasks/TaskFilters.jsx`
- Create: `frontend/src/tasks/TaskList.jsx`
- Create: `frontend/src/tasks/TaskList.test.jsx`
- Create: `frontend/src/calendar/CalendarPage.jsx`
- Modify: `frontend/src/App.jsx`

- [ ] **Step 1: Write task list filter test**

Create `frontend/src/tasks/TaskList.test.jsx`:

```jsx
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { TaskListPage } from "./TaskList";

function renderTasks(api) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  render(
    <QueryClientProvider client={queryClient}>
      <TaskListPage api={api} title="Tasks" />
    </QueryClientProvider>,
  );
}

describe("TaskListPage", () => {
  it("sends lifecycle and occurrence filters to the backend", async () => {
    const api = {
      tasks: vi.fn().mockResolvedValue({ data: [] }),
    };

    renderTasks(api);
    await userEvent.selectOptions(screen.getByLabelText("Lifecycle status"), "ongoing");
    await userEvent.selectOptions(screen.getByLabelText("Occurrence status"), "planned");

    await waitFor(() =>
      expect(api.tasks).toHaveBeenLastCalledWith(expect.objectContaining({ status: "ongoing", occurrence_status: "planned" })),
    );
  });
});
```

- [ ] **Step 2: Run task list test and verify failure**

Run:

```bash
cd frontend
npm test -- src/tasks/TaskList.test.jsx
```

Expected: FAIL because task list modules do not exist.

- [ ] **Step 3: Add constants**

Create `frontend/src/tasks/taskConstants.js`:

```js
export const taskStatuses = ["", "draft", "pending_acceptance", "ongoing", "completed", "cancelled"];
export const taskScopes = ["", "mine", "delegated_to_me", "created_by_me"];
export const occurrenceStatuses = ["", "planned", "postponed", "executed", "skipped", "superseded", "cancelled"];
export const taskKinds = ["one_time", "recurring"];
export const recurrenceTypes = [
  "every_n_days",
  "every_n_months",
  "specific_dates",
  "day_of_month_parity",
  "every_n_years",
  "weekday_parity",
];
```

- [ ] **Step 4: Add filter component**

Create `frontend/src/tasks/TaskFilters.jsx`:

```jsx
import { occurrenceStatuses, taskScopes, taskStatuses } from "./taskConstants";

function titleize(value) {
  return value ? value.replaceAll("_", " ") : "Any";
}

export function TaskFilters({ filters, onChange, showScope = true }) {
  function setFilter(key, value) {
    onChange({ ...filters, [key]: value });
  }

  return (
    <div className="toolbar">
      {showScope ? (
        <label>
          Scope
          <select value={filters.scope || ""} onChange={(event) => setFilter("scope", event.target.value)}>
            {taskScopes.map((scope) => (
              <option key={scope} value={scope}>
                {titleize(scope)}
              </option>
            ))}
          </select>
        </label>
      ) : null}
      <label>
        Lifecycle status
        <select value={filters.status || ""} onChange={(event) => setFilter("status", event.target.value)}>
          {taskStatuses.map((status) => (
            <option key={status} value={status}>
              {titleize(status)}
            </option>
          ))}
        </select>
      </label>
      <label>
        Occurrence status
        <select value={filters.occurrence_status || ""} onChange={(event) => setFilter("occurrence_status", event.target.value)}>
          {occurrenceStatuses.map((status) => (
            <option key={status} value={status}>
              {titleize(status)}
            </option>
          ))}
        </select>
      </label>
      <label>
        From
        <input type="date" value={filters.from || ""} onChange={(event) => setFilter("from", event.target.value)} />
      </label>
      <label>
        To
        <input type="date" value={filters.to || ""} onChange={(event) => setFilter("to", event.target.value)} />
      </label>
    </div>
  );
}
```

- [ ] **Step 5: Implement task list**

Create `frontend/src/tasks/TaskList.jsx`:

```jsx
import { useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { TaskFilters } from "./TaskFilters";

function compactFilters(filters) {
  return Object.fromEntries(Object.entries(filters).filter(([, value]) => value));
}

export function TaskRow({ task }) {
  const attributes = task.attributes || {};
  const occurrence = attributes.occurrence;

  return (
    <article className="table-card">
      <div className="row-between">
        <div>
          <h3>{attributes.name}</h3>
          <p>{attributes.description || "No description"}</p>
        </div>
        <Link to={`/tasks/${String(task.id).split(":")[0]}`}>Open</Link>
      </div>
      <dl className="meta-grid">
        <div><dt>Status</dt><dd>{attributes.status}</dd></div>
        <div><dt>Kind</dt><dd>{attributes.task_kind}</dd></div>
        <div><dt>Creator</dt><dd>{attributes.creator_id || "none"}</dd></div>
        <div><dt>Responsible</dt><dd>{attributes.responsible_id || "none"}</dd></div>
        <div><dt>Delegated</dt><dd>{attributes.delegated_user_id || "none"}</dd></div>
      </dl>
      {occurrence ? (
        <p className="occurrence-line">
          {occurrence.projected ? "Projected" : "Persisted"} occurrence: {occurrence.status} at {occurrence.occurs_at}
        </p>
      ) : null}
    </article>
  );
}

export function TaskListPage({ api, title = "Tasks", initialFilters = {}, showScope = true }) {
  const [filters, setFilters] = useState(initialFilters);
  const queryFilters = useMemo(() => compactFilters(filters), [filters]);
  const tasks = useQuery({
    queryKey: ["tasks", queryFilters],
    queryFn: () => api.tasks(queryFilters),
  });

  return (
    <section className="stack">
      <div className="page-header">
        <p className="eyebrow">Workspace</p>
        <h2>{title}</h2>
      </div>
      <TaskFilters filters={filters} onChange={setFilters} showScope={showScope} />
      {tasks.isError ? <div className="alert error">{tasks.error.messages?.join(", ") || "Unable to load tasks"}</div> : null}
      {tasks.isLoading ? <div className="page-state">Loading tasks...</div> : null}
      <div className="stack">
        {(tasks.data?.data || []).map((task) => (
          <TaskRow key={task.id} task={task} />
        ))}
      </div>
    </section>
  );
}

export const TasksPage = TaskListPage;
```

- [ ] **Step 6: Implement calendar page**

Create `frontend/src/calendar/CalendarPage.jsx`:

```jsx
import { TaskListPage } from "../tasks/TaskList";

function today() {
  return new Date().toISOString().slice(0, 10);
}

export function CalendarPage({ api }) {
  const current = today();
  return (
    <TaskListPage
      api={api}
      title="Calendar"
      initialFilters={{ from: current, to: current, occurrence_status: "planned" }}
    />
  );
}
```

- [ ] **Step 7: Wire routes**

Add `/tasks`, `/delegated`, and `/calendar` routes in `frontend/src/App.jsx`:

```jsx
import { CalendarPage } from "./calendar/CalendarPage";
import { TaskListPage, TasksPage } from "./tasks/TaskList";

<Route path="/tasks" element={<TasksPage api={api} />} />
<Route
  path="/delegated"
  element={<TaskListPage api={api} title="Delegated" initialFilters={{ scope: "delegated_to_me", status: "pending_acceptance" }} /> }
/>
<Route path="/calendar" element={<CalendarPage api={api} />} />
```

- [ ] **Step 8: Run tests and build**

Run:

```bash
cd frontend
npm test -- src/tasks/TaskList.test.jsx
npm run build
```

Expected: test PASS and build succeeds.

- [ ] **Step 9: Commit**

```bash
git add frontend/src/tasks frontend/src/calendar frontend/src/App.jsx
git commit -m "Add task list filters and calendar view"
```

---

### Task 5: Task Detail, Task Creation, Recurrence, And Occurrence Actions

**Files:**
- Create: `frontend/src/tasks/TaskDetail.jsx`
- Create: `frontend/src/tasks/TaskForm.jsx`
- Create: `frontend/src/recurrence/RecurrenceFields.jsx`
- Create: `frontend/src/tasks/TaskForm.test.jsx`
- Modify: `frontend/src/App.jsx`

- [ ] **Step 1: Write recurrence form test**

Create `frontend/src/tasks/TaskForm.test.jsx`:

```jsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { TaskForm } from "./TaskForm";

describe("TaskForm", () => {
  it("enables specific date fields for recurring tasks", async () => {
    render(<TaskForm onSubmit={vi.fn()} />);

    await userEvent.selectOptions(screen.getByLabelText("Task kind"), "recurring");
    await userEvent.selectOptions(screen.getByLabelText("Rule type"), "specific_dates");

    expect(screen.getByLabelText("Specific dates")).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run test and verify failure**

Run:

```bash
cd frontend
npm test -- src/tasks/TaskForm.test.jsx
```

Expected: FAIL because form modules do not exist.

- [ ] **Step 3: Implement recurrence fields**

Create `frontend/src/recurrence/RecurrenceFields.jsx`:

```jsx
import { recurrenceTypes } from "../tasks/taskConstants";

function label(value) {
  return value.replaceAll("_", " ");
}

export function RecurrenceFields({ value, onChange }) {
  function setField(key, fieldValue) {
    onChange({ ...value, [key]: fieldValue });
  }

  const ruleType = value.rule_type || "every_n_days";

  return (
    <fieldset className="panel">
      <legend>Recurrence</legend>
      <div className="form-grid">
        <label>
          Rule type
          <select value={ruleType} onChange={(event) => setField("rule_type", event.target.value)}>
            {recurrenceTypes.map((type) => (
              <option key={type} value={type}>{label(type)}</option>
            ))}
          </select>
        </label>
        <label>
          Start date
          <input type="date" value={value.date_start || ""} onChange={(event) => setField("date_start", event.target.value)} />
        </label>
        <label>
          End date
          <input type="date" value={value.date_end || ""} onChange={(event) => setField("date_end", event.target.value)} />
        </label>
        <label>
          Execution time
          <input type="time" value={value.execution_time || ""} onChange={(event) => setField("execution_time", event.target.value)} />
        </label>
        <label>
          Timezone
          <input value={value.timezone || "Europe/Moscow"} onChange={(event) => setField("timezone", event.target.value)} />
        </label>
      </div>
      {ruleType === "every_n_days" ? (
        <label>
          Interval days
          <input type="number" min="1" value={value.interval_value || 1} onChange={(event) => setField("interval_value", event.target.value)} />
        </label>
      ) : null}
      {ruleType === "every_n_months" ? (
        <div className="form-grid">
          <label><span>Interval months</span><input type="number" min="1" value={value.interval_value || 1} onChange={(event) => setField("interval_value", event.target.value)} /></label>
          <label><span>Day of month</span><input type="number" min="1" max="31" value={value.day_of_month || ""} onChange={(event) => setField("day_of_month", event.target.value)} /></label>
        </div>
      ) : null}
      {ruleType === "day_of_month_parity" ? (
        <label>
          Day parity
          <select value={value.day_of_month_parity || "even"} onChange={(event) => setField("day_of_month_parity", event.target.value)}>
            <option value="even">even</option>
            <option value="odd">odd</option>
          </select>
        </label>
      ) : null}
      {ruleType === "specific_dates" ? (
        <label>
          Specific dates
          <textarea
            value={value.specific_dates || ""}
            onChange={(event) => setField("specific_dates", event.target.value)}
            placeholder="2026-05-15, 2026-05-20"
          />
        </label>
      ) : null}
    </fieldset>
  );
}
```

- [ ] **Step 4: Implement task form**

Create `frontend/src/tasks/TaskForm.jsx`:

```jsx
import { useState } from "react";
import { RecurrenceFields } from "../recurrence/RecurrenceFields";
import { taskKinds } from "./taskConstants";

function recurrencePayload(rule) {
  if (!rule || !rule.rule_type) return undefined;
  const dates = (rule.specific_dates || "")
    .split(",")
    .map((date) => date.trim())
    .filter(Boolean)
    .map((run_date) => ({ run_date }));

  return {
    rule_type: rule.rule_type,
    interval_value: rule.interval_value || undefined,
    day_of_month: rule.day_of_month || undefined,
    day_of_month_parity: rule.day_of_month_parity || undefined,
    month_of_year: rule.month_of_year || undefined,
    weekday: rule.weekday || undefined,
    weekday_parity: rule.weekday_parity || undefined,
    execution_time: rule.execution_time || undefined,
    timezone: rule.timezone || "Europe/Moscow",
    date_start: rule.date_start || undefined,
    date_end: rule.date_end || undefined,
    recurrence_rule_dates_attributes: dates,
  };
}

export function TaskForm({ onSubmit }) {
  const [task, setTask] = useState({ task_kind: "one_time", assign_to_self: true });
  const [recurrence, setRecurrence] = useState({ rule_type: "every_n_days", interval_value: 1, timezone: "Europe/Moscow" });

  function setField(key, value) {
    setTask((current) => ({ ...current, [key]: value }));
  }

  function submit(event) {
    event.preventDefault();
    const payload = {
      ...task,
      recurrence_rule_attributes: task.task_kind === "recurring" ? recurrencePayload(recurrence) : undefined,
    };
    onSubmit(payload);
  }

  return (
    <form className="stack" onSubmit={submit}>
      <div className="form-grid">
        <label>Name<input value={task.name || ""} onChange={(event) => setField("name", event.target.value)} required /></label>
        <label>Task kind
          <select value={task.task_kind} onChange={(event) => setField("task_kind", event.target.value)}>
            {taskKinds.map((kind) => <option key={kind} value={kind}>{kind.replaceAll("_", " ")}</option>)}
          </select>
        </label>
        <label>Completion date<input type="date" value={task.completion_date || ""} onChange={(event) => setField("completion_date", event.target.value)} /></label>
        <label>First run<input type="datetime-local" value={task.first_run_at || ""} onChange={(event) => setField("first_run_at", event.target.value)} /></label>
        <label>Next run<input type="datetime-local" value={task.next_run_at || ""} onChange={(event) => setField("next_run_at", event.target.value)} /></label>
        <label>Delegated user id<input type="number" value={task.delegated_user_id || ""} onChange={(event) => setField("delegated_user_id", event.target.value)} /></label>
      </div>
      <label>Description<textarea value={task.description || ""} onChange={(event) => setField("description", event.target.value)} /></label>
      {task.task_kind === "recurring" ? <RecurrenceFields value={recurrence} onChange={setRecurrence} /> : null}
      <button type="submit">Create task</button>
    </form>
  );
}
```

- [ ] **Step 5: Implement detail view**

Create `frontend/src/tasks/TaskDetail.jsx`:

```jsx
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";
import { useParams } from "react-router-dom";

function mutationOptions(queryClient) {
  return {
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["tasks"] });
      queryClient.invalidateQueries({ queryKey: ["task"] });
    },
  };
}

export function TaskDetail({ api }) {
  const { id } = useParams();
  const queryClient = useQueryClient();
  const task = useQuery({ queryKey: ["task", id], queryFn: () => api.task(id) });
  const accept = useMutation({ mutationFn: () => api.acceptTask(id), ...mutationOptions(queryClient) });
  const decline = useMutation({ mutationFn: () => api.declineTask(id), ...mutationOptions(queryClient) });
  const deactivate = useMutation({ mutationFn: () => api.deactivateTask(id), ...mutationOptions(queryClient) });
  const [postponedTo, setPostponedTo] = useState("");
  const [skipReason, setSkipReason] = useState("");

  if (task.isLoading) return <div className="page-state">Loading task...</div>;
  if (task.isError) return <div className="alert error">{task.error.messages?.join(", ") || "Unable to load task"}</div>;

  const payload = task.data.data;
  const attributes = payload.attributes;
  const occurrence = attributes.occurrence;

  return (
    <section className="stack">
      <div className="page-header">
        <p className="eyebrow">Task</p>
        <h2>{attributes.name}</h2>
        <p>{attributes.description}</p>
      </div>
      <div className="panel">
        <button type="button" onClick={() => accept.mutate()} disabled={attributes.status !== "pending_acceptance"}>Accept</button>
        <button type="button" onClick={() => decline.mutate()} disabled={attributes.status !== "pending_acceptance"}>Decline</button>
        <button type="button" onClick={() => deactivate.mutate()} disabled={["completed", "cancelled"].includes(attributes.status)}>Deactivate</button>
      </div>
      {occurrence?.id ? (
        <div className="panel stack">
          <h3>Occurrence actions</h3>
          <label>Postpone to<input type="datetime-local" value={postponedTo} onChange={(event) => setPostponedTo(event.target.value)} /></label>
          <button type="button" onClick={() => api.postponeOccurrence(occurrence.id, postponedTo)}>Postpone</button>
          <button type="button" onClick={() => api.executeOccurrence(occurrence.id)}>Execute</button>
          <label>Skip reason<input value={skipReason} onChange={(event) => setSkipReason(event.target.value)} /></label>
          <button type="button" onClick={() => api.skipOccurrence(occurrence.id, skipReason)}>Skip</button>
        </div>
      ) : occurrence ? (
        <div className="panel">Projected occurrences are read-only until persisted by the backend.</div>
      ) : null}
    </section>
  );
}
```

- [ ] **Step 6: Wire create and detail routes**

Modify `frontend/src/App.jsx`:

```jsx
import { TaskDetail } from "./tasks/TaskDetail";
import { TaskForm } from "./tasks/TaskForm";

function NewTaskPage({ api }) {
  const mutation = useMutation({ mutationFn: api.createTask });
  return (
    <section className="stack">
      <div className="page-header"><h2>New task</h2></div>
      {mutation.isError ? <div className="alert error">{mutation.error.messages?.join(", ")}</div> : null}
      <TaskForm onSubmit={(task) => mutation.mutate(task)} />
    </section>
  );
}

<Route path="/tasks/new" element={<NewTaskPage api={api} />} />
<Route path="/tasks/:id" element={<TaskDetail api={api} />} />
```

Also import `useMutation` from `@tanstack/react-query` at the top of `App.jsx`.

- [ ] **Step 7: Run tests and build**

Run:

```bash
cd frontend
npm test -- src/tasks/TaskForm.test.jsx
npm run build
```

Expected: test PASS and build succeeds.

- [ ] **Step 8: Commit**

```bash
git add frontend/src/tasks frontend/src/recurrence frontend/src/App.jsx
git commit -m "Add task detail creation and occurrence actions"
```

---

### Task 6: Tags And Admin Views

**Files:**
- Create: `frontend/src/tags/TagsPage.jsx`
- Create: `frontend/src/tags/TagsPage.test.jsx`
- Create: `frontend/src/admin/AdminPage.jsx`
- Modify: `frontend/src/App.jsx`

- [ ] **Step 1: Write system tag immutability test**

Create `frontend/src/tags/TagsPage.test.jsx`:

```jsx
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { TagsPage } from "./TagsPage";

describe("TagsPage", () => {
  it("disables actions for system tags", async () => {
    const api = {
      tags: vi.fn().mockResolvedValue({
        data: [{ id: "1", type: "tag", attributes: { name: "Отчётность", description: "", is_system_tag: true } }],
      }),
    };
    const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });

    render(
      <QueryClientProvider client={queryClient}>
        <TagsPage api={api} />
      </QueryClientProvider>,
    );

    expect(await screen.findByText("Отчётность")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Deactivate" })).toBeDisabled();
  });
});
```

- [ ] **Step 2: Run test and verify failure**

Run:

```bash
cd frontend
npm test -- src/tags/TagsPage.test.jsx
```

Expected: FAIL because `TagsPage.jsx` does not exist.

- [ ] **Step 3: Implement tags page**

Create `frontend/src/tags/TagsPage.jsx`:

```jsx
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useState } from "react";

export function TagsPage({ api, includeDeactivated = false }) {
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const queryClient = useQueryClient();
  const tags = useQuery({ queryKey: ["tags", includeDeactivated], queryFn: () => api.tags({ include_deactivated: includeDeactivated }) });
  const createTag = useMutation({
    mutationFn: () => api.createTag({ name, description }),
    onSuccess: () => {
      setName("");
      setDescription("");
      queryClient.invalidateQueries({ queryKey: ["tags"] });
    },
  });
  const deactivate = useMutation({
    mutationFn: (id) => api.deactivateTag(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["tags"] }),
  });

  return (
    <section className="stack">
      <div className="page-header"><p className="eyebrow">Catalog</p><h2>Tags</h2></div>
      <form className="toolbar" onSubmit={(event) => { event.preventDefault(); createTag.mutate(); }}>
        <label>Name<input value={name} onChange={(event) => setName(event.target.value)} required /></label>
        <label>Description<input value={description} onChange={(event) => setDescription(event.target.value)} /></label>
        <button type="submit">Create tag</button>
      </form>
      <div className="stack">
        {(tags.data?.data || []).map((tag) => (
          <article className="table-card" key={tag.id}>
            <div className="row-between">
              <div>
                <h3>{tag.attributes.name}</h3>
                <p>{tag.attributes.description || "No description"}</p>
                {tag.attributes.is_system_tag ? <strong>System tag</strong> : null}
              </div>
              <button type="button" disabled={tag.attributes.is_system_tag} onClick={() => deactivate.mutate(tag.id)}>
                Deactivate
              </button>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}
```

- [ ] **Step 4: Implement admin page**

Create `frontend/src/admin/AdminPage.jsx`:

```jsx
import { useQuery } from "@tanstack/react-query";
import { TagsPage } from "../tags/TagsPage";
import { TaskListPage } from "../tasks/TaskList";

export function AdminPage({ api }) {
  const health = useQuery({ queryKey: ["health"], queryFn: api.health, retry: false });

  return (
    <section className="stack">
      <div className="page-header">
        <p className="eyebrow">Administrator</p>
        <h2>Admin</h2>
        <p>API health: {health.isLoading ? "Checking" : health.isError ? "Unavailable" : "Available"}</p>
        <a href="/api-docs" target="_blank" rel="noreferrer">Open Swagger</a>
      </div>
      <TaskListPage api={api} title="All visible tasks" showScope={false} />
      <TagsPage api={api} includeDeactivated />
    </section>
  );
}
```

- [ ] **Step 5: Wire routes**

Modify `frontend/src/App.jsx`:

```jsx
import { AdminPage } from "./admin/AdminPage";
import { TagsPage } from "./tags/TagsPage";

<Route path="/tags" element={<TagsPage api={api} />} />
<Route element={<ProtectedRoute adminOnly />}>
  <Route path="/admin" element={<AdminPage api={api} />} />
</Route>
```

- [ ] **Step 6: Run tests and build**

Run:

```bash
cd frontend
npm test -- src/tags/TagsPage.test.jsx
npm run build
```

Expected: test PASS and build succeeds.

- [ ] **Step 7: Commit**

```bash
git add frontend/src/tags frontend/src/admin frontend/src/App.jsx
git commit -m "Add tags and admin frontend views"
```

---

### Task 7: Polish, Full Verification, And Documentation

**Files:**
- Modify: `frontend/src/styles.css`
- Modify: `HISTORY.md`

- [ ] **Step 1: Add missing utility styles**

Append to `frontend/src/styles.css`:

```css
.row-between {
  align-items: flex-start;
  display: flex;
  gap: 1rem;
  justify-content: space-between;
}

.meta-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(140px, 1fr));
  gap: 0.75rem;
  margin: 1rem 0 0;
}

.meta-grid dt {
  color: #667085;
  font-size: 0.8rem;
  font-weight: 700;
}

.meta-grid dd {
  margin: 0.15rem 0 0;
}

.occurrence-line {
  background: #eff8ff;
  border: 1px solid #b2ddff;
  border-radius: 0.5rem;
  margin: 1rem 0 0;
  padding: 0.75rem;
}
```

- [ ] **Step 2: Run full frontend verification**

Run:

```bash
cd frontend
npm test
npm run build
```

Expected: all frontend tests PASS and Vite build succeeds.

- [ ] **Step 3: Start the local frontend**

Run:

```bash
cd frontend
npm run dev -- --host 0.0.0.0
```

Expected: Vite prints a local URL, usually `http://localhost:5173/`.

- [ ] **Step 4: Manual smoke test against Rails**

With the Rails API running, verify:
- login works with a seeded or manually created user.
- `/tasks` loads without a console error.
- `status`, `scope`, date, and `occurrence_status` filters call the backend.
- `/delegated` uses `scope=delegated_to_me&status=pending_acceptance`.
- projected occurrences do not show action buttons.
- persisted occurrences show postpone, execute, and skip actions.
- non-admin users do not see `Admin`.
- admins can open `Admin` and `/api-docs`.

- [ ] **Step 5: Update history**

Append to `HISTORY.md`:

```markdown
- `2026-05-15` - Implemented the hybrid role-based frontend upgrade plan: added auth/session handling, role-aware navigation, task filters, delegated task actions, recurrence task creation, occurrence actions, tag maintenance, admin health/docs view, frontend tests, and verified the frontend build.
```

- [ ] **Step 6: Refresh graph if code changed**

Run:

```bash
graphify update .
```

Expected: graphify updates `graphify-out/` successfully.

- [ ] **Step 7: Commit final polish**

```bash
git add frontend HISTORY.md graphify-out
git commit -m "Complete frontend backend feature upgrade"
```

---

## Plan Self-Review

Spec coverage:
- Auth/session: Task 2.
- Role-aware navigation: Task 3.
- Task filters and date/occurrence projection display: Task 4.
- Task creation, recurrence fields, delegated actions, occurrence actions: Task 5.
- Tags and admin layer: Task 6.
- Verification and history: Task 7.

Known implementation constraints:
- The first frontend iteration uses numeric `delegated_user_id` because there is no users list/search endpoint.
- Attached tag display is conditional because task payloads currently do not guarantee attached tag state.
- User management is deliberately excluded because the backend does not expose user CRUD/list endpoints.
