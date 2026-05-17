import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import { CalendarPage } from "./CalendarPage";

function renderCalendar(api) {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });

  render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter>
        <CalendarPage api={api} initialDate={new Date("2026-05-17T09:00:00+03:00")} />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe("CalendarPage", () => {
  it("loads the visible month and shows tasks on calendar days", async () => {
    const api = {
      tasks: vi.fn().mockResolvedValue({
        data: [
          {
            id: "7:42",
            attributes: {
              name: "Утренний обход",
              occurrence: {
                id: 42,
                status: "planned",
                scheduled_at: "2026-05-17T09:30:00.000+03:00",
              },
            },
          },
        ],
      }),
    };

    renderCalendar(api);

    await waitFor(() =>
      expect(api.tasks).toHaveBeenCalledWith({
        from: "2026-05-01",
        to: "2026-05-31",
        occurrence_status: "planned",
      }),
    );
    expect(await screen.findAllByText("Утренний обход")).toHaveLength(2);
    expect(screen.getByText("09:30")).toBeInTheDocument();
  });

  it("moves to the next month", async () => {
    const api = {
      tasks: vi.fn().mockResolvedValue({ data: [] }),
    };

    renderCalendar(api);
    await userEvent.click(screen.getByRole("button", { name: "Вперед" }));

    await waitFor(() =>
      expect(api.tasks).toHaveBeenLastCalledWith({
        from: "2026-06-01",
        to: "2026-06-30",
        occurrence_status: "planned",
      }),
    );
  });
});
