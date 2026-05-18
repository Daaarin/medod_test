import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AuthProvider } from "./AuthContext";
import { clearStoredToken } from "./session";
import { LoginPage } from "./LoginPage";

function renderLogin(api, initialEntry = "/login") {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });

  render(
    <QueryClientProvider client={queryClient}>
      <AuthProvider api={api}>
        <MemoryRouter initialEntries={[initialEntry]}>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/register" element={<div>Register page</div>} />
            <Route path="/tasks" element={<div>Tasks page</div>} />
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
  vi.restoreAllMocks();
});

describe("LoginPage", () => {
  it("renders the new login layout", () => {
    renderLogin({
      login: vi.fn(),
      me: vi.fn(),
    });

    expect(screen.getByRole("heading", { name: "Вход" })).toBeInTheDocument();
    expect(screen.getByText("Рабочее пространство для задач, календаря и тегов.")).toBeInTheDocument();
    expect(screen.getByLabelText("Email")).toBeInTheDocument();
    expect(screen.getByLabelText("Пароль")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Показать пароль" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Войти" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Создать аккаунт" })).toHaveAttribute("href", "/register");
  });

  it("toggles password visibility", async () => {
    const user = userEvent.setup();

    renderLogin({
      login: vi.fn(),
      me: vi.fn(),
    });

    const passwordInput = screen.getByLabelText("Пароль");
    expect(passwordInput).toHaveAttribute("type", "password");

    await user.click(screen.getByRole("button", { name: "Показать пароль" }));
    expect(passwordInput).toHaveAttribute("type", "text");
    expect(screen.getByRole("button", { name: "Скрыть пароль" })).toBeInTheDocument();
  });

  it("redirects authenticated users away from login", async () => {
    const api = {
      login: vi.fn(),
      me: vi.fn().mockResolvedValue({
        user: { id: 1, email: "admin@example.test", role: "administrator" },
      }),
    };

    window.localStorage.setItem("medods.authToken", "token");
    renderLogin(api);

    await waitFor(() => expect(screen.getByText("Tasks page")).toBeInTheDocument());
    expect(screen.queryByRole("heading", { name: "Вход" })).not.toBeInTheDocument();
  });
});
