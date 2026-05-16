import { occurrenceStatuses, taskScopes, taskStatuses } from "./taskConstants";

function titleize(value) {
  return value ? value.replaceAll("_", " ") : "Any";
}

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
    <div className="toolbar">
      {showScope && !isHidden("scope", hiddenFilters) ? (
        <label>
          Scope
          <select value={filters.scope || ""} onChange={(event) => setFilter("scope", event.target.value)}>
            {taskScopes.map((scope) => (
              <option key={scope} value={scope}>
                {titleize(scope)}
              </option>
            ))}
          </select>
        </label>
      ) : null}
      {!isHidden("status", hiddenFilters) ? (
        <label>
          Lifecycle status
          <select value={filters.status || ""} onChange={(event) => setFilter("status", event.target.value)}>
            {taskStatuses.map((status) => (
              <option key={status} value={status}>
                {titleize(status)}
              </option>
            ))}
          </select>
        </label>
      ) : null}
      {!isHidden("occurrence_status", hiddenFilters) ? (
        <label>
          Occurrence status
          <select
            aria-describedby={occurrenceStatusHelpId}
            disabled={!hasDateRange}
            title={hasDateRange ? undefined : "Set From or To before filtering by occurrence status"}
            value={filters.occurrence_status || ""}
            onChange={(event) => setFilter("occurrence_status", event.target.value)}
          >
            {occurrenceStatuses.map((status) => (
              <option key={status} value={status}>
                {titleize(status)}
              </option>
            ))}
          </select>
          {!hasDateRange ? <span id="occurrence-status-help">Date range required.</span> : null}
        </label>
      ) : null}
      {!isHidden("from", hiddenFilters) ? (
        <label>
          From
          <input type="date" value={filters.from || ""} onChange={(event) => setFilter("from", event.target.value)} />
        </label>
      ) : null}
      {!isHidden("to", hiddenFilters) ? (
        <label>
          To
          <input type="date" value={filters.to || ""} onChange={(event) => setFilter("to", event.target.value)} />
        </label>
      ) : null}
    </div>
  );
}
