import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { act, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AuthProvider, useAuth } from "./AuthContext";
import { clearStoredToken, notifyUnauthorized } from "./session";

function Probe() {
  const auth = useAuth();
  return (
    <div>
      <span>{auth.user?.email || "anonymous"}</span>
      <span>{auth.error || "no-error"}</span>
      <button onClick={() => auth.login({ email: "admin@example.test", password: "secret" })}>
        login
      </button>
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

afterEach(() => {
  clearStoredToken();
  vi.restoreAllMocks();
});

beforeEach(() => {
  clearStoredToken();
});

describe("AuthProvider", () => {
  it("logs in and exposes the current user", async () => {
    const api = {
      login: vi.fn().mockResolvedValue({
        token: "token-1",
        user: { id: 1, email: "admin@example.test", role: "administrator" },
      }),
      me: vi.fn().mockResolvedValue({
        user: { id: 1, email: "admin@example.test", role: "administrator" },
      }),
    };

    renderAuth(api);
    await userEvent.click(screen.getByRole("button", { name: "login" }));

    await waitFor(() => expect(screen.getByText("admin@example.test")).toBeInTheDocument());
    expect(window.localStorage.getItem("medods.authToken")).toBe("token-1");
  });

  it("clears the session when unauthorized is notified", async () => {
    const api = {
      login: vi.fn().mockResolvedValue({
        token: "token-1",
        user: { id: 1, email: "admin@example.test", role: "administrator" },
      }),
      me: vi.fn().mockResolvedValue({
        user: { id: 1, email: "admin@example.test", role: "administrator" },
      }),
    };

    renderAuth(api);
    await userEvent.click(screen.getByRole("button", { name: "login" }));

    await waitFor(() => expect(screen.getByText("admin@example.test")).toBeInTheDocument());

    act(() => {
      notifyUnauthorized();
    });

    await waitFor(() => expect(screen.getByText("anonymous")).toBeInTheDocument());
    expect(window.localStorage.getItem("medods.authToken")).toBeNull();
  });

  it("preserves the stored token when me fails with a server error", async () => {
    const api = {
      login: vi.fn(),
      me: vi.fn().mockRejectedValue({
        status: 500,
        messages: ["Backend unavailable"],
      }),
    };

    window.localStorage.setItem("medods.authToken", "persisted-token");
    renderAuth(api);

    await waitFor(() => expect(api.me).toHaveBeenCalled());
    expect(window.localStorage.getItem("medods.authToken")).toBe("persisted-token");
    expect(screen.getByText("Backend unavailable")).toBeInTheDocument();
    expect(screen.getByText("anonymous")).toBeInTheDocument();
  });

  it("keeps the logged-in user visible when me fails after login with a server error", async () => {
    const api = {
      login: vi.fn().mockResolvedValue({
        token: "token-2",
        user: { id: 2, email: "doctor@example.test", role: "doctor" },
      }),
      me: vi.fn().mockRejectedValue({
        status: 500,
        messages: ["Backend unavailable"],
      }),
    };

    renderAuth(api);
    await userEvent.click(screen.getByRole("button", { name: "login" }));

    await waitFor(() => expect(screen.getByText("doctor@example.test")).toBeInTheDocument());
    expect(window.localStorage.getItem("medods.authToken")).toBe("token-2");
    expect(screen.getByText("Backend unavailable")).toBeInTheDocument();
  });
});
