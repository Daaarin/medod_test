import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { AuthProvider } from "./AuthContext";
import { clearStoredToken } from "./session";
import { RegisterPage } from "./RegisterPage";

function renderRegister(api) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });

  render(
    <QueryClientProvider client={queryClient}>
      <AuthProvider api={api}>
        <MemoryRouter initialEntries={["/register"]}>
          <Routes>
            <Route path="/login" element={<div>Login page</div>} />
            <Route path="/register" element={<RegisterPage />} />
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

describe("RegisterPage", () => {
  it("submits the signup form and logs the user in", async () => {
    const user = userEvent.setup();
    const api = {
      register: vi.fn().mockResolvedValue({
        token: "token-1",
        user: { id: 7, email: "new@example.test", role: "doctor" },
      }),
      me: vi.fn().mockResolvedValue({
        user: { id: 7, email: "new@example.test", role: "doctor" },
      }),
    };

    renderRegister(api);

    await user.type(screen.getByLabelText("Email"), "new@example.test");
    await user.type(screen.getByLabelText("Пароль"), "password123");
    await user.type(screen.getByLabelText("Имя"), "Anna");
    await user.type(screen.getByLabelText("Фамилия"), "Sidorova");
    await user.selectOptions(screen.getByLabelText("Роль"), "doctor");
    await user.click(screen.getByRole("button", { name: "Создать аккаунт" }));

    await waitFor(() => expect(screen.getByText("Tasks page")).toBeInTheDocument());
    expect(api.register).toHaveBeenCalledWith({
      email: "new@example.test",
      password: "password123",
      name: "Anna",
      last_name: "Sidorova",
      role: "doctor",
    });
    expect(window.localStorage.getItem("medods.authToken")).toBe("token-1");
  });
});
