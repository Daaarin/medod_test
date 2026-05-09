import { NavLink, Route, Routes } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";

const apiBase = import.meta.env.VITE_API_BASE_URL || "http://localhost:3000";

function fetchHealth() {
  return fetch(`${apiBase}/up`).then(async (response) => {
    if (!response.ok) {
      throw new Error(`Health check failed with ${response.status}`);
    }

    return response.text();
  });
}

function Shell({ children }) {
  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div>
          <p className="eyebrow">API service</p>
          <h1>Medods Admin</h1>
          <p className="sidebar-copy">
            React + Vite for a fast multi-tab admin panel with client-side routing and cached queries.
          </p>
        </div>

        <nav className="tabs" aria-label="Primary">
          <NavLink to="/" end>
            Overview
          </NavLink>
          <NavLink to="/users">Users</NavLink>
          <NavLink to="/activity">Activity</NavLink>
          <NavLink to="/settings">Settings</NavLink>
        </nav>
      </aside>

      <main className="content">{children}</main>
    </div>
  );
}

function Stat({ label, value }) {
  return (
    <div className="card stat">
      <span>{label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function Overview() {
  const health = useQuery({ queryKey: ["health"], queryFn: fetchHealth });

  return (
    <section className="stack">
      <div className="hero">
        <div>
          <p className="eyebrow">Dashboard</p>
          <h2>Fast navigation without full reloads.</h2>
          <p>
            Use nested routes and cached fetches for a lightweight admin panel that feels native.
          </p>
        </div>

        <div className="grid">
          <Stat label="Routing" value="Client-side" />
          <Stat label="API" value={health.isLoading ? "Checking..." : health.data ?? "Offline"} />
          <Stat label="DB" value="PostgreSQL 16" />
          <Stat label="Docs" value="Swagger / OpenAPI" />
        </div>
      </div>

      <div className="card">
        <h3>Backend status</h3>
        <p className={health.isError ? "status error" : "status ok"}>
          {health.isError
            ? "Rails is unreachable from the frontend container."
            : health.isLoading
              ? "Loading status from the API..."
              : "Rails API is responding at /up."}
        </p>
      </div>
    </section>
  );
}

function PlaceholderPage({ title, description }) {
  return (
    <section className="card stack">
      <div>
        <p className="eyebrow">Admin tab</p>
        <h2>{title}</h2>
        <p>{description}</p>
      </div>
    </section>
  );
}

export default function App() {
  return (
    <Shell>
      <Routes>
        <Route path="/" element={<Overview />} />
        <Route
          path="/users"
          element={
            <PlaceholderPage
              title="Users"
              description="A dedicated route for user management, with local tab state preserved by the SPA."
            />
          }
        />
        <Route
          path="/activity"
          element={
            <PlaceholderPage
              title="Activity"
              description="A route for logs, jobs, and live updates without forcing a page refresh."
            />
          }
        />
        <Route
          path="/settings"
          element={
            <PlaceholderPage
              title="Settings"
              description="A place for feature flags, API keys, and admin controls."
            />
          }
        />
      </Routes>
    </Shell>
  );
}
