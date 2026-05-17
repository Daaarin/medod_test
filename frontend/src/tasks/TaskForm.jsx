import { useMemo, useState } from "react";
import { RecurrenceFields } from "../recurrence/RecurrenceFields";
import { labelFrom, taskKindLabels, taskKinds } from "./taskConstants";

function localDateTimeToIso(value) {
  if (!value) return "";
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? value : parsed.toISOString();
}

function recurrencePayload(rule) {
  if (!rule || !rule.rule_type) return undefined;

  const recurrenceRuleDatesAttributes = (rule.specific_dates || "")
    .split(",")
    .map((date) => date.trim())
    .filter(Boolean)
    .map((run_date) => ({ run_date }));

  return {
    rule_type: rule.rule_type,
    interval_value: rule.interval_value || undefined,
    day_of_month: rule.day_of_month || undefined,
    day_of_month_parity:
      rule.rule_type === "day_of_month_parity" ? rule.day_of_month_parity || "even" : undefined,
    month_of_year: rule.month_of_year || undefined,
    weekday: rule.weekday || undefined,
    weekday_parity: rule.rule_type === "weekday_parity" ? rule.weekday_parity || "even" : undefined,
    execution_time: rule.execution_time || undefined,
    timezone: rule.timezone || "Europe/Moscow",
    date_start: rule.date_start || undefined,
    date_end: rule.date_end || undefined,
    recurrence_rule_dates_attributes: recurrenceRuleDatesAttributes,
  };
}

export function TaskForm({ onSubmit, submitLabel = "Создать задачу" }) {
  const [task, setTask] = useState({
    task_kind: "one_time",
    assign_to_self: true,
    completion_date: "",
    first_run_at: "",
    next_run_at: "",
    delegated_user_id: "",
    name: "",
    description: "",
  });
  const [recurrence, setRecurrence] = useState({
    rule_type: "every_n_days",
    interval_value: 1,
    timezone: "Europe/Moscow",
  });

  const isRecurring = task.task_kind === "recurring";

  function setField(key, value) {
    setTask((current) => ({ ...current, [key]: value }));
  }

  const payload = useMemo(() => {
    const base = {
      ...task,
      completion_date: task.completion_date || undefined,
      first_run_at: localDateTimeToIso(task.first_run_at),
      next_run_at: localDateTimeToIso(task.next_run_at),
      delegated_user_id: task.delegated_user_id || undefined,
      assign_to_self: Boolean(task.assign_to_self),
    };

    if (base.first_run_at === "") delete base.first_run_at;
    if (base.next_run_at === "") delete base.next_run_at;

    if (isRecurring) {
      base.recurrence_rule_attributes = recurrencePayload(recurrence);
    }

    return base;
  }, [isRecurring, recurrence, task]);

  function submit(event) {
    event.preventDefault();
    onSubmit(payload);
  }

  return (
    <form className="stack task-form" onSubmit={submit}>
      <div className="form-grid task-form-grid">
        <label>
          Название
          <input value={task.name} onChange={(event) => setField("name", event.target.value)} required />
        </label>
        <label>
          Тип задачи
          <select value={task.task_kind} onChange={(event) => setField("task_kind", event.target.value)}>
            {taskKinds.map((kind) => (
              <option key={kind} value={kind}>
                {labelFrom(taskKindLabels, kind)}
              </option>
            ))}
          </select>
        </label>
        <label>
          Дата завершения
          <input
            type="date"
            value={task.completion_date}
            onChange={(event) => setField("completion_date", event.target.value)}
          />
        </label>
        <label>
          Первый запуск
          <input
            type="datetime-local"
            value={task.first_run_at}
            onChange={(event) => setField("first_run_at", event.target.value)}
          />
        </label>
        <label>
          Следующий запуск
          <input
            type="datetime-local"
            value={task.next_run_at}
            onChange={(event) => setField("next_run_at", event.target.value)}
          />
        </label>
        <label>
          ID делегированного пользователя
          <input
            type="number"
            min="1"
            value={task.delegated_user_id}
            onChange={(event) => setField("delegated_user_id", event.target.value)}
          />
        </label>
      </div>

      <label>
        Описание
        <textarea value={task.description} onChange={(event) => setField("description", event.target.value)} />
      </label>

      <label>
        <span>Назначить на меня</span>
        <input
          type="checkbox"
          checked={task.assign_to_self}
          onChange={(event) => setField("assign_to_self", event.target.checked)}
        />
      </label>

      {isRecurring ? <RecurrenceFields value={recurrence} onChange={setRecurrence} /> : null}

      <button type="submit">{submitLabel}</button>
    </form>
  );
}
