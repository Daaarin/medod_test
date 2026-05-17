import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { TaskForm } from "./TaskForm";

const users = [
  {
    id: 11,
    attributes: {
      role: "doctor",
      last_name: "Иванов",
      name: "Иван",
      display_name: "Врач Иванов Иван",
    },
  },
];

describe("TaskForm", () => {
  it("enables specific date fields for recurring tasks", async () => {
    const user = userEvent.setup();
    render(<TaskForm onSubmit={vi.fn()} />);

    await user.selectOptions(screen.getByLabelText("Тип задачи"), "recurring");
    await user.selectOptions(screen.getByLabelText("Тип правила"), "specific_dates");

    expect(screen.getByLabelText("Конкретные даты")).toBeInTheDocument();
    expect(screen.getByLabelText("Следующий запуск")).toHaveValue("—");
  });

  it("shows delegated-user selection only when self-assignment is disabled", async () => {
    const user = userEvent.setup();
    render(<TaskForm onSubmit={vi.fn()} users={users} canAssignDelegates />);

    expect(screen.queryByLabelText("Пользователь для делегирования")).not.toBeInTheDocument();

    await user.click(screen.getByLabelText("Назначить на меня"));
    expect(screen.getByLabelText("Пользователь для делегирования")).toBeInTheDocument();
    expect(screen.getByRole("option", { name: "Врач Иванов Иван (11)" })).toBeInTheDocument();

    await user.selectOptions(screen.getByLabelText("Пользователь для делегирования"), "11");
    await user.click(screen.getByLabelText("Назначить на меня"));

    expect(screen.queryByLabelText("Пользователь для делегирования")).not.toBeInTheDocument();
  });

  it("converts recurring submit values to task payload fields without next_run_at", async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();
    render(<TaskForm onSubmit={onSubmit} users={users} canAssignDelegates />);

    await user.type(screen.getByLabelText("Название"), "Morning rounds");
    await user.selectOptions(screen.getByLabelText("Тип задачи"), "recurring");
    await user.selectOptions(screen.getByLabelText("Тип правила"), "specific_dates");
    await user.type(screen.getByLabelText("Конкретные даты"), "2026-05-16, 2026-05-20");
    await user.type(screen.getByLabelText("Дата завершения"), "2026-05-21");
    await user.type(screen.getByLabelText("Первый запуск"), "2026-05-16T09:30");
    await user.click(screen.getByLabelText("Назначить на меня"));
    await user.selectOptions(screen.getByLabelText("Пользователь для делегирования"), "11");
    await user.click(screen.getByRole("button", { name: "Создать задачу" }));

    await waitFor(() => expect(onSubmit).toHaveBeenCalledTimes(1));
    expect(onSubmit).toHaveBeenCalledWith(
      expect.objectContaining({
        name: "Morning rounds",
        task_kind: "recurring",
        first_run_at: "2026-05-16T06:30:00.000Z",
        delegated_user_id: "11",
        recurrence_rule_attributes: expect.objectContaining({
          rule_type: "specific_dates",
          recurrence_rule_dates_attributes: [{ run_date: "2026-05-16" }, { run_date: "2026-05-20" }],
        }),
      }),
    );
    expect(onSubmit.mock.calls[0][0]).not.toHaveProperty("next_run_at");
  });

  it("copies the first run into next_run_at for one-time tasks", async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();
    render(<TaskForm onSubmit={onSubmit} />);

    await user.type(screen.getByLabelText("Название"), "Single visit");
    await user.type(screen.getByLabelText("Первый запуск"), "2026-05-16T09:30");
    await user.click(screen.getByRole("button", { name: "Создать задачу" }));

    await waitFor(() => expect(onSubmit).toHaveBeenCalledTimes(1));
    expect(onSubmit).toHaveBeenCalledWith(
      expect.objectContaining({
        first_run_at: "2026-05-16T06:30:00.000Z",
        next_run_at: "2026-05-16T06:30:00.000Z",
      }),
    );
  });

  it("blocks completion dates that are not after the initial schedule", async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();
    render(<TaskForm onSubmit={onSubmit} />);

    await user.type(screen.getByLabelText("Название"), "Weekly review");
    await user.selectOptions(screen.getByLabelText("Тип задачи"), "recurring");
    await user.type(screen.getByLabelText("Дата завершения"), "2026-05-15");
    await user.type(screen.getByLabelText("Первый запуск"), "2026-05-16T09:30");
    await user.click(screen.getByRole("button", { name: "Создать задачу" }));

    expect(onSubmit).not.toHaveBeenCalled();
    expect(screen.getByText("Дата завершения должна быть позже первого и следующего запуска")).toBeInTheDocument();
  });
});
