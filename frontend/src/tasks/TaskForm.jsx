import { useEffect, useMemo, useState } from "react";
import { RecurrenceFields } from "../recurrence/RecurrenceFields";
import {
  computeRecurringNextRunDate,
  computeRecurringNextRunPreview,
  datePartFromDateTimeInput,
  formatUserLabel,
} from "../utils/display";
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

function delegatedUserLabel(user) {
  return formatUserLabel(user, { includeId: true });
}

function dateOrderError(completionDate, firstRunAt, nextRunDate) {
  if (!completionDate) return "";

  const completionKey = completionDate;
  const firstRunKey = datePartFromDateTimeInput(firstRunAt);
  const nextRunKey = nextRunDate || "";
  const relevantDates = [firstRunKey, nextRunKey].filter(Boolean);

  if (!relevantDates.length) return "";
  if (relevantDates.some((dateKey) => completionKey <= dateKey)) {
    return "Дата завершения должна быть позже первого и следующего запуска";
  }

  return "";
}

export function TaskForm({
  onSubmit,
  submitLabel = "Создать задачу",
  users = [],
  usersLoading = false,
  usersError = null,
  canAssignDelegates = false,
}) {
  const [task, setTask] = useState({
    task_kind: "one_time",
    assign_to_self: true,
    completion_date: "",
    first_run_at: "",
    delegated_user_id: "",
    name: "",
    description: "",
  });
  const [recurrence, setRecurrence] = useState({
    rule_type: "every_n_days",
    interval_value: 1,
    timezone: "Europe/Moscow",
    execution_time: "12:00",
  });
  const [error, setError] = useState("");

  const isRecurring = task.task_kind === "recurring";
  const nextRunPreview = useMemo(() => (isRecurring ? computeRecurringNextRunPreview(recurrence) : ""), [isRecurring, recurrence]);
  const nextRunDate = useMemo(() => (isRecurring ? computeRecurringNextRunDate(recurrence) : ""), [isRecurring, recurrence]);

  useEffect(() => {
    if (task.assign_to_self && task.delegated_user_id) {
      setTask((current) => ({ ...current, delegated_user_id: "" }));
    }
  }, [task.assign_to_self, task.delegated_user_id]);

  function setField(key, value) {
    setTask((current) => ({ ...current, [key]: value }));
  }

  const payload = useMemo(() => {
    const base = {
      ...task,
      completion_date: task.completion_date || undefined,
      first_run_at: localDateTimeToIso(task.first_run_at),
      assign_to_self: Boolean(task.assign_to_self),
    };

    if (base.first_run_at === "") delete base.first_run_at;

    if (task.assign_to_self || !task.delegated_user_id) {
      delete base.delegated_user_id;
    } else {
      base.delegated_user_id = task.delegated_user_id;
    }

    if (isRecurring) {
      base.recurrence_rule_attributes = recurrencePayload(recurrence);
    }

    return base;
  }, [isRecurring, recurrence, task]);

  function submit(event) {
    event.preventDefault();
    const validationError = dateOrderError(task.completion_date, task.first_run_at, nextRunDate);
    if (validationError) {
      setError(validationError);
      return;
    }

    setError("");
    onSubmit(payload);
  }

  const delegateUsers = Array.isArray(users) ? users : [];

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
      </div>

      <div className="task-assignee-row">
        <label className="switch-control">
          <span>Назначить на меня</span>
          <span className="switch-control-body">
            <input
              type="checkbox"
              checked={task.assign_to_self}
              onChange={(event) => setField("assign_to_self", event.target.checked)}
            />
            <span className="switch-track" aria-hidden="true">
              <span className="switch-thumb" />
            </span>
          </span>
        </label>

        {canAssignDelegates && !task.assign_to_self ? (
          <label className="task-delegate-select">
            Пользователь для делегирования
            <select value={task.delegated_user_id} onChange={(event) => setField("delegated_user_id", event.target.value)}>
              <option value="">Не выбран</option>
              {usersLoading ? <option value="" disabled>Загружаем пользователей...</option> : null}
              {delegateUsers.map((user) => (
                <option key={user.id} value={user.id}>
                  {delegatedUserLabel(user)}
                </option>
              ))}
            </select>
          </label>
        ) : null}
      </div>

      {usersError ? <div className="alert error">{usersError}</div> : null}
      {task.assign_to_self ? null : canAssignDelegates ? null : <div className="page-state">Делегирование недоступно.</div>}

      <label>
        Описание
        <textarea value={task.description} onChange={(event) => setField("description", event.target.value)} />
      </label>

      {error ? <div className="alert error">{error}</div> : null}

      {isRecurring ? <RecurrenceFields value={recurrence} onChange={setRecurrence} nextRunPreview={nextRunPreview} /> : null}

      <button type="submit">{submitLabel}</button>
    </form>
  );
}
