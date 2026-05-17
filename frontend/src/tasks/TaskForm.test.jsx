import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { TaskForm } from "./TaskForm";

describe("TaskForm", () => {
  it("enables specific date fields for recurring tasks", async () => {
    render(<TaskForm onSubmit={vi.fn()} />);

    await userEvent.selectOptions(screen.getByLabelText("Тип задачи"), "recurring");
    await userEvent.selectOptions(screen.getByLabelText("Тип правила"), "specific_dates");

    expect(screen.getByLabelText("Конкретные даты")).toBeInTheDocument();
  });

  it("enables weekday parity fields for recurring tasks", async () => {
    render(<TaskForm onSubmit={vi.fn()} />);

    await userEvent.selectOptions(screen.getByLabelText("Тип задачи"), "recurring");
    await userEvent.selectOptions(screen.getByLabelText("Тип правила"), "weekday_parity");

    expect(screen.getByLabelText("Четность дня недели")).toBeInTheDocument();
    expect(screen.getByLabelText("Четность дня недели")).toHaveValue("even");
  });

  it("converts recurring submit values to task payload fields", async () => {
    const onSubmit = vi.fn();
    render(<TaskForm onSubmit={onSubmit} />);

    await userEvent.type(screen.getByLabelText("Название"), "Morning rounds");
    await userEvent.selectOptions(screen.getByLabelText("Тип задачи"), "recurring");
    await userEvent.selectOptions(screen.getByLabelText("Тип правила"), "specific_dates");
    await userEvent.type(screen.getByLabelText("Конкретные даты"), "2026-05-16, 2026-05-20");
    await userEvent.type(screen.getByLabelText("Первый запуск"), "2026-05-16T09:30");
    await userEvent.click(screen.getByRole("button", { name: "Создать задачу" }));

    expect(onSubmit).toHaveBeenCalledWith(
      expect.objectContaining({
        name: "Morning rounds",
        task_kind: "recurring",
        first_run_at: "2026-05-16T06:30:00.000Z",
        recurrence_rule_attributes: expect.objectContaining({
          rule_type: "specific_dates",
          recurrence_rule_dates_attributes: [{ run_date: "2026-05-16" }, { run_date: "2026-05-20" }],
        }),
      }),
    );
  });

  it("submits weekday parity when the weekday parity rule is selected", async () => {
    const onSubmit = vi.fn();
    render(<TaskForm onSubmit={onSubmit} />);

    await userEvent.type(screen.getByLabelText("Название"), "Evening check");
    await userEvent.selectOptions(screen.getByLabelText("Тип задачи"), "recurring");
    await userEvent.selectOptions(screen.getByLabelText("Тип правила"), "weekday_parity");
    await userEvent.selectOptions(screen.getByLabelText("Четность дня недели"), "odd");
    await userEvent.click(screen.getByRole("button", { name: "Создать задачу" }));

    expect(onSubmit).toHaveBeenCalledWith(
      expect.objectContaining({
        name: "Evening check",
        task_kind: "recurring",
        recurrence_rule_attributes: expect.objectContaining({
          rule_type: "weekday_parity",
          weekday_parity: "odd",
        }),
      }),
    );
  });

  it("submits day parity default as even when unchanged", async () => {
    const onSubmit = vi.fn();
    render(<TaskForm onSubmit={onSubmit} />);

    await userEvent.type(screen.getByLabelText("Название"), "Midmonth review");
    await userEvent.selectOptions(screen.getByLabelText("Тип задачи"), "recurring");
    await userEvent.selectOptions(screen.getByLabelText("Тип правила"), "day_of_month_parity");
    await userEvent.click(screen.getByRole("button", { name: "Создать задачу" }));

    expect(onSubmit).toHaveBeenCalledWith(
      expect.objectContaining({
        name: "Midmonth review",
        task_kind: "recurring",
        recurrence_rule_attributes: expect.objectContaining({
          rule_type: "day_of_month_parity",
          day_of_month_parity: "even",
        }),
      }),
    );
  });

  it("submits weekday parity default as even when unchanged", async () => {
    const onSubmit = vi.fn();
    render(<TaskForm onSubmit={onSubmit} />);

    await userEvent.type(screen.getByLabelText("Название"), "Weekly review");
    await userEvent.selectOptions(screen.getByLabelText("Тип задачи"), "recurring");
    await userEvent.selectOptions(screen.getByLabelText("Тип правила"), "weekday_parity");
    await userEvent.click(screen.getByRole("button", { name: "Создать задачу" }));

    expect(onSubmit).toHaveBeenCalledWith(
      expect.objectContaining({
        name: "Weekly review",
        task_kind: "recurring",
        recurrence_rule_attributes: expect.objectContaining({
          rule_type: "weekday_parity",
          weekday_parity: "even",
        }),
      }),
    );
  });
});
