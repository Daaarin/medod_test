import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import { AuthProvider } from "../auth/AuthContext";
import { clearStoredToken } from "../auth/session";
import { Shell } from "./Shell";

function renderShell(user) {
  const api = { me: async () => ({ user }) };
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });

  window.localStorage.setItem("medods.authToken", "token");

  render(
    <QueryClientProvider client={queryClient}>
      <AuthProvider api={api}>
        <MemoryRouter initialEntries={["/tasks"]}>
          <Routes>
            <Route element={<Shell />}>
              <Route path="/tasks" element={<div>Tasks content</div>} />
            </Route>
          </Routes>
        </MemoryRouter>
      </AuthProvider>
    </QueryClientProvider>,
  );
}

beforeEach(() => {
  clearStoredToken();
});

afterEach(() => {
  clearStoredToken();
});

describe("Shell", () => {
  it("hides admin navigation for staff users", async () => {
    renderShell({
      id: 2,
      email: "nurse@example.test",
      role: "nurse",
      name: "Nina",
      last_name: "Nurse",
    });

    expect(await screen.findByText("Tasks content")).toBeInTheDocument();
    await waitFor(() => expect(screen.getByText("Nina Nurse")).toBeInTheDocument());
    expect(screen.queryByRole("link", { name: "Администрирование" })).not.toBeInTheDocument();
  });

  it("shows admin navigation for administrators", async () => {
    renderShell({
      id: 1,
      email: "admin@example.test",
      role: "administrator",
      name: "Ada",
      last_name: "Admin",
    });

    expect(await screen.findByText("Tasks content")).toBeInTheDocument();
    await waitFor(() => expect(screen.getByText("Ada Admin")).toBeInTheDocument());
    expect(await screen.findByRole("link", { name: "Администрирование" })).toBeInTheDocument();
  });
});
