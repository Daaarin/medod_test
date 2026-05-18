import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { TaskDetail } from "./TaskDetail";

const authState = vi.hoisted(() => ({
  value: {
    user: { id: 1, role: "doctor" },
    isAdmin: false,
  },
}));

vi.mock("../auth/AuthContext", () => ({
  useAuth: () => authState.value,
}));

function renderTaskDetail(api, state) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: {
        retry: false,
      },
    },
  });

  render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[{ pathname: "/tasks/123", state }]}>
        <Routes>
          <Route path="/tasks/:taskId" element={<TaskDetail api={api} />} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe("TaskDetail", () => {
  beforeEach(() => {
    authState.value = {
      user: { id: 1, role: "doctor" },
      isAdmin: false,
    };
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("updates occurrence state from the transition response instead of keeping stale navigation state", async () => {
    vi.spyOn(Date, "now").mockReturnValue(new Date("2026-05-16T10:00:00.000Z").getTime());
    const user = userEvent.setup();
    const api = {
      task: vi.fn().mockResolvedValue({
        data: {
          id: "123",
          attributes: {
            name: "Morning rounds",
            description: "",
            status: "ongoing",
            task_kind: "recurring",
            creator_id: 1,
            responsible_id: 2,
            creator: {
              id: 1,
              attributes: {
                role: "doctor",
                last_name: "Иванов",
                name: "Иван",
                display_name: "Врач Иванов Иван",
              },
            },
            responsible: {
              id: 2,
              attributes: {
                role: "nurse",
                last_name: "Петрова",
                name: "Анна",
                display_name: "Медсестра Петрова Анна",
              },
            },
            delegated_user: {
              id: 3,
              attributes: {
                role: "administrator",
                last_name: "Сидоров",
                name: "Алексей",
                display_name: "Администратор Сидоров Алексей",
              },
            },
          },
        },
      }),
      tags: vi.fn().mockResolvedValue({ data: [] }),
      updateTask: vi.fn(),
      acceptTask: vi.fn(),
      declineTask: vi.fn(),
      deactivateTask: vi.fn(),
      postponeOccurrence: vi.fn(),
      executeOccurrence: vi.fn().mockResolvedValue({
        data: {
          occurrence: {
            id: "42",
            type: "task_occurrence",
            attributes: {
              scheduled_at: "2026-05-16T09:30:00.000Z",
              actual_at: "2026-05-16T09:45:00.000Z",
              status: "executed",
            },
          },
          task: {
            id: "123",
            type: "task",
            attributes: {
              name: "Morning rounds",
              description: "",
              status: "ongoing",
              task_kind: "recurring",
            },
          },
        },
      }),
      skipOccurrence: vi.fn(),
      attachTag: vi.fn(),
      detachTag: vi.fn(),
    };

    renderTaskDetail(api, {
      occurrence: {
        id: 42,
        scheduled_at: "2026-05-16T09:30:00.000Z",
        occurs_at: "2026-05-16T09:30:00.000Z",
        status: "planned",
        projected: false,
      },
    });

    expect(await screen.findByRole("button", { name: "Выполнено" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Отложить" })).toBeInTheDocument();
    expect(screen.getByText("Врач Иванов Иван")).toBeInTheDocument();
    expect(screen.getByText("Медсестра Петрова Анна")).toBeInTheDocument();
    expect(screen.getByText("Администратор Сидоров Алексей")).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Выполнено" }));

    await waitFor(() => expect(api.executeOccurrence).toHaveBeenCalledWith(42));
    await waitFor(() => expect(screen.queryByRole("button", { name: "Выполнено" })).not.toBeInTheDocument());
    await waitFor(() => expect(screen.getByText("Выполнено")).toBeInTheDocument());
    expect(screen.getByText("16-05-2026 09:45 (UTC +0)")).toBeInTheDocument();
  });

  it("hides occurrence actions from users who are neither author nor responsible nor admin", async () => {
    authState.value = {
      user: { id: 99, role: "nurse" },
      isAdmin: false,
    };

    const api = {
      task: vi.fn().mockResolvedValue({
        data: {
          id: "123",
          attributes: {
            name: "Morning rounds",
            description: "",
            status: "ongoing",
            task_kind: "recurring",
            creator_id: 1,
            responsible_id: 2,
          },
        },
      }),
      tags: vi.fn().mockResolvedValue({ data: [] }),
      updateTask: vi.fn(),
      acceptTask: vi.fn(),
      declineTask: vi.fn(),
      deactivateTask: vi.fn(),
      postponeOccurrence: vi.fn(),
      executeOccurrence: vi.fn(),
      skipOccurrence: vi.fn(),
      attachTag: vi.fn(),
      detachTag: vi.fn(),
    };

    renderTaskDetail(api, {
      occurrence: {
        id: 42,
        scheduled_at: "2026-05-16T09:30:00.000Z",
        occurs_at: "2026-05-16T09:30:00.000Z",
        status: "planned",
        projected: false,
      },
    });

    expect(await screen.findByText("Для этого выполнения нет действий.")).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Выполнено" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Отложить" })).not.toBeInTheDocument();
  });

  it("disables completion for later-today occurrences until their actionable time arrives", async () => {
    vi.spyOn(Date, "now").mockReturnValue(new Date("2026-05-16T09:00:00.000Z").getTime());

    const api = {
      task: vi.fn().mockResolvedValue({
        data: {
          id: "123",
          attributes: {
            name: "Morning rounds",
            description: "",
            status: "ongoing",
            task_kind: "recurring",
            creator_id: 1,
            responsible_id: 2,
          },
        },
      }),
      tags: vi.fn().mockResolvedValue({ data: [] }),
      updateTask: vi.fn(),
      acceptTask: vi.fn(),
      declineTask: vi.fn(),
      deactivateTask: vi.fn(),
      postponeOccurrence: vi.fn(),
      executeOccurrence: vi.fn(),
      skipOccurrence: vi.fn(),
      attachTag: vi.fn(),
      detachTag: vi.fn(),
    };

    renderTaskDetail(api, {
      occurrence: {
        id: 42,
        scheduled_at: "2026-05-16T09:30:00.000Z",
        occurs_at: "2026-05-16T09:30:00.000Z",
        status: "planned",
        projected: false,
      },
    });

    expect(await screen.findByRole("button", { name: "Выполнено" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Отложить" })).toBeEnabled();
  });

  it("shows occurrence actions to administrators even when they are not the author or responsible", async () => {
    authState.value = {
      user: { id: 77, role: "administrator" },
      isAdmin: true,
    };

    const api = {
      task: vi.fn().mockResolvedValue({
        data: {
          id: "123",
          attributes: {
            name: "Morning rounds",
            description: "",
            status: "ongoing",
            task_kind: "recurring",
            creator_id: 1,
            responsible_id: 2,
          },
        },
      }),
      tags: vi.fn().mockResolvedValue({ data: [] }),
      updateTask: vi.fn(),
      acceptTask: vi.fn(),
      declineTask: vi.fn(),
      deactivateTask: vi.fn(),
      postponeOccurrence: vi.fn(),
      executeOccurrence: vi.fn(),
      skipOccurrence: vi.fn(),
      attachTag: vi.fn(),
      detachTag: vi.fn(),
    };

    renderTaskDetail(api, {
      occurrence: {
        id: 42,
        scheduled_at: "2026-05-16T09:30:00.000Z",
        occurs_at: "2026-05-16T09:30:00.000Z",
        status: "planned",
        projected: false,
      },
    });

    expect(await screen.findByRole("button", { name: "Выполнено" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Отложить" })).toBeInTheDocument();
  });

  it("sends null when a saved completion date is cleared", async () => {
    const user = userEvent.setup();
    const api = {
      task: vi.fn().mockResolvedValue({
        data: {
          id: "123",
          attributes: {
            name: "Morning rounds",
            description: "",
            status: "ongoing",
            task_kind: "recurring",
            completion_date: "2026-05-16",
          },
        },
      }),
      tags: vi.fn().mockResolvedValue({ data: [] }),
      updateTask: vi.fn().mockResolvedValue({ data: { id: "123", attributes: {} } }),
      acceptTask: vi.fn(),
      declineTask: vi.fn(),
      deactivateTask: vi.fn(),
      postponeOccurrence: vi.fn(),
      executeOccurrence: vi.fn(),
      skipOccurrence: vi.fn(),
      attachTag: vi.fn(),
      detachTag: vi.fn(),
    };

    renderTaskDetail(api);

    const completionDateInput = await screen.findByLabelText("Дата завершения");
    await user.clear(completionDateInput);
    await user.click(screen.getByRole("button", { name: "Сохранить" }));

    await waitFor(() =>
      expect(api.updateTask).toHaveBeenCalledWith(
        "123",
        expect.objectContaining({
          name: "Morning rounds",
          description: "",
          completion_date: null,
        }),
      ),
    );
    expect(api.updateTask.mock.calls[0][1]).not.toHaveProperty("recurrence_rule_attributes");
  });

  it("keeps the recurrence end-date payload when the task has a persisted recurrence rule", async () => {
    const user = userEvent.setup();
    const api = {
      task: vi.fn().mockResolvedValue({
        data: {
          id: "123",
          attributes: {
            name: "Morning rounds",
            description: "",
            status: "ongoing",
            task_kind: "recurring",
            completion_date: "2026-05-16",
            recurrence_rule: {
              id: "88",
              attributes: {
                date_end: "2026-05-16",
              },
            },
          },
        },
      }),
      tags: vi.fn().mockResolvedValue({ data: [] }),
      updateTask: vi.fn().mockResolvedValue({ data: { id: "123", attributes: {} } }),
      acceptTask: vi.fn(),
      declineTask: vi.fn(),
      deactivateTask: vi.fn(),
      postponeOccurrence: vi.fn(),
      executeOccurrence: vi.fn(),
      skipOccurrence: vi.fn(),
      attachTag: vi.fn(),
      detachTag: vi.fn(),
    };

    renderTaskDetail(api);

    const completionDateInput = await screen.findByLabelText("Дата завершения");
    await user.clear(completionDateInput);
    await user.click(screen.getByRole("button", { name: "Сохранить" }));

    await waitFor(() =>
      expect(api.updateTask).toHaveBeenCalledWith(
        "123",
        expect.objectContaining({
          name: "Morning rounds",
          description: "",
          completion_date: null,
          recurrence_rule_attributes: { id: "88", date_end: null },
        }),
      ),
    );
  });
});
