import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";
import { TaskForm } from "./TaskForm";

describe("TaskForm", () => {
  it("enables specific date fields for recurring tasks", async () => {
    render(<TaskForm onSubmit={vi.fn()} />);

    await userEvent.selectOptions(screen.getByLabelText("Task kind"), "recurring");
    await userEvent.selectOptions(screen.getByLabelText("Rule type"), "specific_dates");

    expect(screen.getByLabelText("Specific dates")).toBeInTheDocument();
  });

  it("enables weekday parity fields for recurring tasks", async () => {
    render(<TaskForm onSubmit={vi.fn()} />);

    await userEvent.selectOptions(screen.getByLabelText("Task kind"), "recurring");
    await userEvent.selectOptions(screen.getByLabelText("Rule type"), "weekday_parity");

    expect(screen.getByLabelText("Weekday parity")).toBeInTheDocument();
    expect(screen.getByLabelText("Weekday parity")).toHaveValue("even");
  });

  it("converts recurring submit values to task payload fields", async () => {
    const onSubmit = vi.fn();
    render(<TaskForm onSubmit={onSubmit} />);

    await userEvent.type(screen.getByLabelText("Name"), "Morning rounds");
    await userEvent.selectOptions(screen.getByLabelText("Task kind"), "recurring");
    await userEvent.selectOptions(screen.getByLabelText("Rule type"), "specific_dates");
    await userEvent.type(screen.getByLabelText("Specific dates"), "2026-05-16, 2026-05-20");
    await userEvent.type(screen.getByLabelText("First run"), "2026-05-16T09:30");
    await userEvent.click(screen.getByRole("button", { name: "Create task" }));

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

    await userEvent.type(screen.getByLabelText("Name"), "Evening check");
    await userEvent.selectOptions(screen.getByLabelText("Task kind"), "recurring");
    await userEvent.selectOptions(screen.getByLabelText("Rule type"), "weekday_parity");
    await userEvent.selectOptions(screen.getByLabelText("Weekday parity"), "odd");
    await userEvent.click(screen.getByRole("button", { name: "Create task" }));

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

    await userEvent.type(screen.getByLabelText("Name"), "Midmonth review");
    await userEvent.selectOptions(screen.getByLabelText("Task kind"), "recurring");
    await userEvent.selectOptions(screen.getByLabelText("Rule type"), "day_of_month_parity");
    await userEvent.click(screen.getByRole("button", { name: "Create task" }));

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

    await userEvent.type(screen.getByLabelText("Name"), "Weekly review");
    await userEvent.selectOptions(screen.getByLabelText("Task kind"), "recurring");
    await userEvent.selectOptions(screen.getByLabelText("Rule type"), "weekday_parity");
    await userEvent.click(screen.getByRole("button", { name: "Create task" }));

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
