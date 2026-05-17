import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
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
      <MemoryRouter>
        <TaskListPage api={api} />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe("TaskListPage", () => {
  it("defaults the from filter to today and keeps occurrence filters without a date range", async () => {
    const api = {
      tasks: vi.fn().mockResolvedValue({ data: [] }),
    };
    const user = userEvent.setup();

    renderTasks(api);

    await waitFor(() =>
      expect(api.tasks).toHaveBeenLastCalledWith(
        expect.objectContaining({
          from: expect.any(String),
        }),
      ),
    );

    await user.clear(screen.getByLabelText("С"));
    await user.selectOptions(screen.getByLabelText("Статус задачи"), "ongoing");
    await user.selectOptions(screen.getByLabelText("Статус выполнения"), "planned");

    await waitFor(() =>
      expect(api.tasks).toHaveBeenLastCalledWith(
        expect.objectContaining({
          status: "ongoing",
          occurrence_status: "planned",
        }),
      ),
    );
    expect(api.tasks).toHaveBeenLastCalledWith(
      expect.not.objectContaining({
        from: expect.any(String),
      }),
    );
  });

  it("renders nested user labels and formatted dates", async () => {
    const api = {
      tasks: vi.fn().mockResolvedValue({
        data: [
          {
            id: "7",
            attributes: {
              name: "Утренний обход",
              status: "ongoing",
              task_kind: "one_time",
              creator: {
                id: 1,
                attributes: {
                  role: "administrator",
                  last_name: "Сидоров",
                  name: "Алексей",
                  display_name: "Администратор Сидоров Алексей",
                },
              },
              responsible: {
                id: 2,
                attributes: {
                  role: "doctor",
                  last_name: "Иванов",
                  name: "Иван",
                  display_name: "Врач Иванов Иван",
                },
              },
              delegated_user: {
                id: 3,
                attributes: {
                  role: "nurse",
                  last_name: "Петрова",
                  name: "Анна",
                  display_name: "Медсестра Петрова Анна",
                },
              },
              first_run_at: "2026-05-17T09:30:00.000+03:00",
              completion_date: "2026-05-18",
            },
          },
        ],
      }),
    };

    renderTasks(api);

    expect(await screen.findByText("Администратор Сидоров Алексей")).toBeInTheDocument();
    expect(screen.getByText("Врач Иванов Иван")).toBeInTheDocument();
    expect(screen.getByText("Медсестра Петрова Анна")).toBeInTheDocument();
    expect(screen.getByText("17-05-2026 09:30 (UTC +3)")).toBeInTheDocument();
    expect(screen.getByText("18-05-2026")).toBeInTheDocument();
  });
});
