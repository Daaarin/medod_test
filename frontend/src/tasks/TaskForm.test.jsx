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
});
