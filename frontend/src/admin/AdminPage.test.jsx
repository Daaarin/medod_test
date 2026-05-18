import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AdminPage } from "./AdminPage";

vi.mock("../api/client", () => ({
  apiBase: "http://localhost:3000",
}));

vi.mock("../tags/TagsPage", () => ({
  TagsPage: () => <div data-testid="tags-page" />,
}));

vi.mock("../tasks/TaskList", () => ({
  TaskListPage: () => <div data-testid="task-list-page" />,
}));

function renderAdminPage(api) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

  render(
    <QueryClientProvider client={queryClient}>
      <AdminPage api={api} />
    </QueryClientProvider>,
  );
}

describe("AdminPage", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("opens Swagger from the backend origin instead of the frontend origin", async () => {
    const api = {
      health: vi.fn().mockResolvedValue({}),
    };

    renderAdminPage(api);

    const link = screen.getByRole("link", { name: "Открыть Swagger" });
    expect(link).toHaveAttribute("href", "http://localhost:3000/api-docs");
  });
});
