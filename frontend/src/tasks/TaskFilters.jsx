import {
  labelFrom,
  occurrenceStatusLabels,
  occurrenceStatuses,
  scopeLabels,
  taskScopes,
  taskStatuses,
  statusLabels,
} from "./taskConstants";

function isHidden(field, hiddenFilters) {
  return hiddenFilters.includes(field);
}

export function TaskFilters({ filters, onChange, showScope = true, hiddenFilters = [] }) {
  const hasDateRange = Boolean(filters.from || filters.to);
  const occurrenceStatusHelpId = hasDateRange ? undefined : "occurrence-status-help";

  function setFilter(key, value) {
    onChange({ ...filters, [key]: value });
  }

  return (
    <div className="toolbar filter-toolbar">
      {showScope && !isHidden("scope", hiddenFilters) ? (
        <label>
          Область
          <select value={filters.scope || ""} onChange={(event) => setFilter("scope", event.target.value)}>
            {taskScopes.map((scope) => (
              <option key={scope} value={scope}>
                {labelFrom(scopeLabels, scope)}
              </option>
            ))}
          </select>
        </label>
      ) : null}
      {!isHidden("status", hiddenFilters) ? (
        <label>
          Статус задачи
          <select value={filters.status || ""} onChange={(event) => setFilter("status", event.target.value)}>
            {taskStatuses.map((status) => (
              <option key={status} value={status}>
                {labelFrom(statusLabels, status)}
              </option>
            ))}
          </select>
        </label>
      ) : null}
      {!isHidden("occurrence_status", hiddenFilters) ? (
        <label>
          Статус выполнения
          <select
            aria-describedby={occurrenceStatusHelpId}
            disabled={!hasDateRange}
            title={hasDateRange ? undefined : "Укажите дату начала или окончания"}
            value={filters.occurrence_status || ""}
            onChange={(event) => setFilter("occurrence_status", event.target.value)}
          >
            {occurrenceStatuses.map((status) => (
              <option key={status} value={status}>
                {labelFrom(occurrenceStatusLabels, status)}
              </option>
            ))}
          </select>
          {!hasDateRange ? (
            <span className="field-help" id="occurrence-status-help">
              Нужен период.
            </span>
          ) : null}
        </label>
      ) : null}
      {!isHidden("from", hiddenFilters) ? (
        <label>
          С
          <input type="date" value={filters.from || ""} onChange={(event) => setFilter("from", event.target.value)} />
        </label>
      ) : null}
      {!isHidden("to", hiddenFilters) ? (
        <label>
          По
          <input type="date" value={filters.to || ""} onChange={(event) => setFilter("to", event.target.value)} />
        </label>
      ) : null}
    </div>
  );
}
