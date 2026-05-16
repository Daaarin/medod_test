import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
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
  it("keeps occurrence actions available when navigation state carries the occurrence context", async () => {
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

    expect(await screen.findByRole("button", { name: "Execute" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Postpone" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Skip" })).toBeInTheDocument();
  });
});
