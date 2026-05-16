import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { TaskListPage } from "./TaskList";

function renderTasks(api) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

  render(
    <QueryClientProvider client={queryClient}>
      <TaskListPage api={api} />
    </QueryClientProvider>,
  );
}

describe("TaskListPage", () => {
  it("sends lifecycle and occurrence filters to the backend", async () => {
    const api = {
      tasks: vi.fn().mockResolvedValue({ data: [] }),
    };
    const user = userEvent.setup();

    renderTasks(api);

    await user.type(screen.getByLabelText("From"), "2026-05-15");
    await user.selectOptions(screen.getByLabelText("Lifecycle status"), "ongoing");
    await user.selectOptions(screen.getByLabelText("Occurrence status"), "planned");

    await waitFor(() =>
      expect(api.tasks).toHaveBeenLastCalledWith(
        expect.objectContaining({
          from: "2026-05-15",
          status: "ongoing",
          occurrence_status: "planned",
        }),
      ),
    );
  });
});
