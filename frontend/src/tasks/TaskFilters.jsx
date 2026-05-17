import {
  labelFrom,
  occurrenceStatusLabels,
  occurrenceStatuses,
  scopeLabels,
  taskScopes,
  taskStatuses,
  statusLabels,
} from "./taskConstants";
import { formatDateInputValue, parseDateInputValue } from "../utils/display";

function isHidden(field, hiddenFilters) {
  return hiddenFilters.includes(field);
}

export function TaskFilters({ filters, onChange, showScope = true, hiddenFilters = [] }) {
  function setFilter(key, value) {
    onChange({ ...filters, [key]: value });
  }

  return (
    <div className="toolbar filter-toolbar">
      {showScope && !isHidden("scope", hiddenFilters) ? (
        <label>
          Принадлежность
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
          <select value={filters.occurrence_status || ""} onChange={(event) => setFilter("occurrence_status", event.target.value)}>
            {occurrenceStatuses.map((status) => (
              <option key={status} value={status}>
                {labelFrom(occurrenceStatusLabels, status)}
              </option>
            ))}
          </select>
        </label>
      ) : null}
      {!isHidden("from", hiddenFilters) ? (
        <label>
          С
          <input
            type="text"
            inputMode="numeric"
            placeholder="ДД-ММ-ГГГГ"
            value={formatDateInputValue(filters.from)}
            onChange={(event) => setFilter("from", parseDateInputValue(event.target.value))}
          />
        </label>
      ) : null}
      {!isHidden("to", hiddenFilters) ? (
        <label>
          По
          <input
            type="text"
            inputMode="numeric"
            placeholder="ДД-ММ-ГГГГ"
            value={formatDateInputValue(filters.to)}
            onChange={(event) => setFilter("to", parseDateInputValue(event.target.value))}
          />
        </label>
      ) : null}
    </div>
  );
}
