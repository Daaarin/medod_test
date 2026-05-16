import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import { TaskDetail } from "./TaskDetail";

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
  it("updates occurrence state from the transition response instead of keeping stale navigation state", async () => {
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

    expect(await screen.findByRole("button", { name: "Execute" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Postpone" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Skip" })).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Execute" }));

    await waitFor(() =>
      expect(api.executeOccurrence).toHaveBeenCalledWith(42),
    );
    await waitFor(() =>
      expect(screen.queryByRole("button", { name: "Execute" })).not.toBeInTheDocument(),
    );
    await waitFor(() =>
      expect(screen.getByText("executed")).toBeInTheDocument(),
    );
    expect(screen.getByText("2026-05-16T09:45:00.000Z")).toBeInTheDocument();
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

    const completionDateInput = await screen.findByLabelText("Completion date");
    await user.clear(completionDateInput);
    await user.click(screen.getByRole("button", { name: "Save changes" }));

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
  });
});
