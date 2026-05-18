import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen, waitFor, within } from "@testing-library/react";
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
  it("loads the visible month and shows previews with overflow markers", async () => {
    const api = {
      tasks: vi.fn().mockImplementation(({ occurrence_status }) =>
        Promise.resolve({
          data:
            occurrence_status === "planned"
              ? [
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
                  {
                    id: "8:43",
                    attributes: {
                      name: "Поздний обход",
                      occurrence: {
                        id: 43,
                        status: "planned",
                        scheduled_at: "2026-05-17T10:30:00.000+03:00",
                      },
                    },
                  },
                ]
              : [
                  {
                    id: "9:44",
                    attributes: {
                      name: "Ночная проверка",
                      occurrence: {
                        id: 44,
                        status: "postponed",
                        scheduled_at: "2026-05-16T11:30:00.000+03:00",
                        postponed_to: "2026-05-17T11:30:00.000+03:00",
                        occurs_at: "2026-05-17T11:30:00.000+03:00",
                      },
                    },
                  },
                ],
        }),
      ),
    };

    renderCalendar(api);

    await waitFor(() =>
      expect(api.tasks).toHaveBeenNthCalledWith(1, {
        from: "2026-05-01",
        to: "2026-05-31",
        occurrence_status: "planned",
      }),
    );
    await waitFor(() =>
      expect(api.tasks).toHaveBeenNthCalledWith(2, {
        from: "2026-05-01",
        to: "2026-05-31",
        occurrence_status: "postponed",
      }),
    );

    const selectedDayButton = screen.getByRole("button", { name: /17/ });
    await waitFor(() => expect(within(selectedDayButton).getByText("Утренний обход")).toBeInTheDocument());
    expect(within(selectedDayButton).getByText("Поздний обход")).toBeInTheDocument();
    expect(within(selectedDayButton).getByText("+1")).toBeInTheDocument();

    expect(screen.getByText("Задачи дня")).toBeInTheDocument();
    const agendaItems = await screen.findAllByRole("link", { name: /Утренний обход|Поздний обход|Ночная проверка/ });
    expect(agendaItems[0]).toHaveTextContent("09:30 (UTC +3)");
    expect(agendaItems[1]).toHaveTextContent("10:30 (UTC +3)");
    expect(agendaItems[2]).toHaveTextContent("11:30 (UTC +3)");
    expect(agendaItems[2]).toHaveTextContent("Перенесено");
  });

  it("shows recurrence end dates in the day agenda", async () => {
    const api = {
      tasks: vi.fn().mockImplementation(({ occurrence_status }) =>
        Promise.resolve({
          data:
            occurrence_status === "planned"
              ? [
                  {
                    id: "10:50",
                    attributes: {
                      name: "Курс процедур",
                      recurrence_rule: {
                        id: "50",
                        type: "recurrence_rule",
                        attributes: {
                          date_end: "2026-05-22",
                        },
                      },
                      occurrence: {
                        id: 50,
                        status: "planned",
                        scheduled_at: "2026-05-17T09:30:00.000+03:00",
                      },
                    },
                  },
                ]
              : [],
        }),
      ),
    };

    renderCalendar(api);

    const agendaItem = await screen.findByRole("link", { name: /Курс процедур/ });
    expect(agendaItem).toHaveTextContent("Повторяется до 22-05-2026");
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
        occurrence_status: "postponed",
      }),
    );
  });
});
