import { useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { TaskFilters } from "./TaskFilters";
import { labelFrom, occurrenceStatusLabels, statusLabels, taskKindLabels } from "./taskConstants";
import { formatDate, formatDateTime, formatUserLabel, todayIsoDate } from "../utils/display";

function compactFilters(filters = {}) {
  return Object.fromEntries(
    Object.entries(filters).filter(([, value]) => value !== undefined && value !== null && value !== ""),
  );
}

function readError(error) {
  if (error?.messages?.length) {
    return error.messages.join(", ");
  }

  if (typeof error?.message === "string" && error.message.trim()) {
    return error.message;
  }

  return "Не удалось загрузить задачи";
}

function rowTitle(task) {
  return task?.attributes?.name || "Без названия";
}

function userValue(user) {
  return formatUserLabel(user);
}

export function TaskRow({ task }) {
  const attributes = task?.attributes ?? {};
  const occurrence = attributes.occurrence ?? null;
  const baseTaskId = String(task?.id ?? "").split(":")[0];
  const occurrenceTime = occurrence?.occurs_at || occurrence?.scheduled_at;
  const planningTime = attributes.first_run_at || attributes.next_run_at || occurrenceTime;
  const dueDate = attributes.completion_date;

  return (
    <tr>
      <td className="task-title-cell">
        <strong>{rowTitle(task)}</strong>
        <p>{attributes.description || "Описание не добавлено"}</p>
      </td>
      <td className="task-meta">
        <span className="task-row-badge">
          <span className="status-badge">{labelFrom(statusLabels, attributes.status, "—")}</span>
          {occurrence ? (
            <span className="task-subline">
              {labelFrom(occurrenceStatusLabels, occurrence.status, "—")}
              {occurrenceTime ? ` • ${formatDateTime(occurrenceTime)}` : ""}
            </span>
          ) : null}
        </span>
      </td>
      <td>{labelFrom(taskKindLabels, attributes.task_kind, "—")}</td>
      <td className="task-meta">{userValue(attributes.creator)}</td>
      <td className="task-meta">{userValue(attributes.responsible)}</td>
      <td className="task-meta">{userValue(attributes.delegated_user)}</td>
      <td className="task-meta">{planningTime ? formatDateTime(planningTime) : "—"}</td>
      <td className="task-meta">{dueDate ? formatDate(dueDate) : "—"}</td>
      <td className="task-actions">
        {baseTaskId ? (
          <Link className="inline-action" to={`/tasks/${baseTaskId}`} state={occurrence ? { occurrence } : undefined}>
            Открыть
          </Link>
        ) : null}
      </td>
    </tr>
  );
}

function compactQueryFilters(filters) {
  return compactFilters(filters);
}

export function TaskListPage({
  api,
  title = "Задачи",
  initialFilters = {},
  showScope = true,
  hiddenFilters = [],
  primaryAction = null,
}) {
  const [filters, setFilters] = useState(() => ({ from: todayIsoDate(), ...initialFilters }));
  const queryFilters = useMemo(() => compactQueryFilters(filters), [filters]);

  const tasksQuery = useQuery({
    queryKey: ["tasks", queryFilters],
    queryFn: () => api.tasks(queryFilters),
  });

  const rows = tasksQuery.data?.data || [];

  return (
    <section className="stack">
      <header className="page-header">
        <div>
          <p className="eyebrow">Рабочая область</p>
          <h2>{title}</h2>
          <p className="header-copy">Плотный список задач с фильтрами и быстрым переходом в карточку.</p>
        </div>
        {primaryAction ? (
          <Link className="page-action" to={primaryAction.to}>
            {primaryAction.label}
          </Link>
        ) : null}
      </header>
      <section className="task-list-shell">
        <TaskFilters filters={filters} onChange={setFilters} showScope={showScope} hiddenFilters={hiddenFilters} />
        {tasksQuery.isPending ? <div className="page-state">Загружаем задачи...</div> : null}
        {tasksQuery.isError ? <div className="page-state alert error">{readError(tasksQuery.error)}</div> : null}
        {!tasksQuery.isPending && !tasksQuery.isError && rows.length === 0 ? (
          <div className="page-state">Задачи не найдены.</div>
        ) : null}
        {!tasksQuery.isPending && !tasksQuery.isError && rows.length > 0 ? (
          <div className="table-card">
            <table className="task-table" aria-label={title}>
              <thead>
                <tr>
                  <th>Название</th>
                  <th>Статус</th>
                  <th>Тип</th>
                  <th>Автор</th>
                  <th>Ответственный</th>
                  <th>Делегировано</th>
                  <th>Запуск</th>
                  <th>Срок</th>
                  <th>Действие</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((task) => (
                  <TaskRow key={task.id} task={task} />
                ))}
              </tbody>
            </table>
          </div>
        ) : null}
      </section>
    </section>
  );
}

export const TasksPage = TaskListPage;
