import { useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { TaskFilters } from "./TaskFilters";

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

  return "Unable to load tasks";
}

function displayValue(value) {
  return value ?? "—";
}

function rowTitle(task) {
  return task?.attributes?.name || "Untitled task";
}

export function TaskRow({ task }) {
  const attributes = task?.attributes ?? {};
  const occurrence = attributes.occurrence ?? null;
  const baseTaskId = String(task?.id ?? "").split(":")[0];
  const occurrenceTime = occurrence?.occurs_at || occurrence?.scheduled_at;
  const occurrenceLabel = occurrence?.projected ? "Projected" : "Occurrence";

  return (
    <article className="table-card">
      <div style={{ display: "flex", justifyContent: "space-between", gap: "1rem", alignItems: "flex-start" }}>
        <div style={{ minWidth: 0 }}>
          <h3>{rowTitle(task)}</h3>
          <p>{attributes.description || "No description"}</p>
        </div>
        {baseTaskId ? <Link to={`/tasks/${baseTaskId}`}>Open</Link> : null}
      </div>
      <dl className="stack">
        <div>
          <dt>Status</dt>
          <dd>{displayValue(attributes.status)}</dd>
        </div>
        <div>
          <dt>Kind</dt>
          <dd>{displayValue(attributes.task_kind)}</dd>
        </div>
        <div>
          <dt>Creator</dt>
          <dd>{displayValue(attributes.creator_id)}</dd>
        </div>
        <div>
          <dt>Responsible</dt>
          <dd>{displayValue(attributes.responsible_id)}</dd>
        </div>
        <div>
          <dt>Delegated</dt>
          <dd>{displayValue(attributes.delegated_user_id)}</dd>
        </div>
      </dl>
      {occurrence ? (
        <p>
          {occurrenceLabel} occurrence: {displayValue(occurrence.status)}
          {occurrenceTime ? ` at ${occurrenceTime}` : ""}
        </p>
      ) : null}
    </article>
  );
}

export function TaskListPage({ api, title = "Tasks", initialFilters = {}, showScope = true }) {
  const [filters, setFilters] = useState(() => ({ ...initialFilters }));
  const queryFilters = useMemo(() => compactFilters(filters), [filters]);

  const tasksQuery = useQuery({
    queryKey: ["tasks", queryFilters],
    queryFn: () => api.tasks(queryFilters),
  });

  const rows = tasksQuery.data?.data || [];

  return (
    <section className="stack">
      <header className="page-header">
        <p className="eyebrow">Workspace</p>
        <h2>{title}</h2>
      </header>
      <TaskFilters filters={filters} onChange={setFilters} showScope={showScope} />
      {tasksQuery.isPending ? <div className="page-state">Loading tasks...</div> : null}
      {tasksQuery.isError ? <div className="alert error">{readError(tasksQuery.error)}</div> : null}
      {!tasksQuery.isPending && !tasksQuery.isError && rows.length === 0 ? (
        <div className="page-state">No tasks found.</div>
      ) : null}
      <div className="stack">
        {rows.map((task) => (
          <TaskRow key={task.id} task={task} />
        ))}
      </div>
    </section>
  );
}

export const TasksPage = TaskListPage;
