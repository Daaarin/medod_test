import { recurrenceTypes } from "../tasks/taskConstants";

function labelFor(value) {
  return value ? value.replaceAll("_", " ") : "";
}

function setNestedField(value, onChange, key, fieldValue) {
  onChange({
    ...value,
    [key]: fieldValue,
  });
}

function ParitySelect({ label, rule, parity, onChange, fieldKey }) {
  return (
    <label>
      {label}
      <select
        value={parity || "even"}
        onChange={(event) => setNestedField(rule, onChange, fieldKey, event.target.value)}
      >
        <option value="even">even</option>
        <option value="odd">odd</option>
      </select>
    </label>
  );
}

export function RecurrenceFields({ value, onChange }) {
  const ruleType = value.rule_type || "every_n_days";

  return (
    <fieldset className="panel">
      <legend>Recurrence</legend>
      <div className="form-grid">
        <label>
          Rule type
          <select
            value={ruleType}
            onChange={(event) => setNestedField(value, onChange, "rule_type", event.target.value)}
          >
            {recurrenceTypes.map((type) => (
              <option key={type} value={type}>
                {labelFor(type)}
              </option>
            ))}
          </select>
        </label>

        <label>
          Start date
          <input
            type="date"
            value={value.date_start || ""}
            onChange={(event) => setNestedField(value, onChange, "date_start", event.target.value)}
          />
        </label>

        <label>
          End date
          <input
            type="date"
            value={value.date_end || ""}
            onChange={(event) => setNestedField(value, onChange, "date_end", event.target.value)}
          />
        </label>

        <label>
          Execution time
          <input
            type="time"
            value={value.execution_time || ""}
            onChange={(event) => setNestedField(value, onChange, "execution_time", event.target.value)}
          />
        </label>

        <label>
          Timezone
          <input
            value={value.timezone || "Europe/Moscow"}
            onChange={(event) => setNestedField(value, onChange, "timezone", event.target.value)}
          />
        </label>
      </div>

      {ruleType === "every_n_days" ? (
        <label>
          Interval days
          <input
            type="number"
            min="1"
            value={value.interval_value || 1}
            onChange={(event) => setNestedField(value, onChange, "interval_value", event.target.value)}
          />
        </label>
      ) : null}

      {ruleType === "every_n_months" ? (
        <div className="form-grid">
          <label>
            Interval months
            <input
              type="number"
              min="1"
              value={value.interval_value || 1}
              onChange={(event) => setNestedField(value, onChange, "interval_value", event.target.value)}
            />
          </label>
          <label>
            Day of month
            <input
              type="number"
              min="1"
              max="31"
              value={value.day_of_month || ""}
              onChange={(event) => setNestedField(value, onChange, "day_of_month", event.target.value)}
            />
          </label>
        </div>
      ) : null}

      {ruleType === "day_of_month_parity" ? (
        <ParitySelect
          label="Day parity"
          rule={value}
          parity={value.day_of_month_parity}
          onChange={onChange}
          fieldKey="day_of_month_parity"
        />
      ) : null}

      {ruleType === "weekday_parity" ? (
        <ParitySelect
          label="Weekday parity"
          rule={value}
          parity={value.weekday_parity}
          onChange={onChange}
          fieldKey="weekday_parity"
        />
      ) : null}

      {ruleType === "specific_dates" ? (
        <label>
          Specific dates
          <textarea
            value={value.specific_dates || ""}
            onChange={(event) => setNestedField(value, onChange, "specific_dates", event.target.value)}
            placeholder="2026-05-15, 2026-05-20"
          />
        </label>
      ) : null}
    </fieldset>
  );
}
