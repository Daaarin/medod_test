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

describe("AuthProvider", () => {
  it("logs in and exposes the current user", async () => {
    window.localStorage.clear();
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
});
