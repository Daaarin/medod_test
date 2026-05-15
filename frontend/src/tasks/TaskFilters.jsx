import { occurrenceStatuses, taskScopes, taskStatuses } from "./taskConstants";

function titleize(value) {
  return value ? value.replaceAll("_", " ") : "Any";
}

export function TaskFilters({ filters, onChange, showScope = true }) {
  function setFilter(key, value) {
    onChange({ ...filters, [key]: value });
  }

  return (
    <div className="toolbar">
      {showScope ? (
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
      <label>
        Occurrence status
        <select
          value={filters.occurrence_status || ""}
          onChange={(event) => setFilter("occurrence_status", event.target.value)}
        >
          {occurrenceStatuses.map((status) => (
            <option key={status} value={status}>
              {titleize(status)}
            </option>
          ))}
        </select>
      </label>
      <label>
        From
        <input type="date" value={filters.from || ""} onChange={(event) => setFilter("from", event.target.value)} />
      </label>
      <label>
        To
        <input type="date" value={filters.to || ""} onChange={(event) => setFilter("to", event.target.value)} />
      </label>
    </div>
  );
}
