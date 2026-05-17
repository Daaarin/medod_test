import {
  computeRecurringNextRunPreview,
  getTimeZoneOptions,
} from "../utils/display";
import { labelFrom, parityLabels, recurrenceTypeLabels, recurrenceTypes } from "../tasks/taskConstants";

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
      <select value={parity || "even"} onChange={(event) => setNestedField(rule, onChange, fieldKey, event.target.value)}>
        <option value="even">{parityLabels.even}</option>
        <option value="odd">{parityLabels.odd}</option>
      </select>
    </label>
  );
}

export function RecurrenceFields({ value, onChange, nextRunPreview = "" }) {
  const ruleType = value.rule_type || "every_n_days";
  const timeZoneOptions = getTimeZoneOptions();
  const computedPreview = nextRunPreview || computeRecurringNextRunPreview(value);

  return (
    <fieldset className="panel recurrence-panel">
      <legend>Повторение</legend>
      <div className="form-grid">
        <label>
          Тип правила
          <select value={ruleType} onChange={(event) => setNestedField(value, onChange, "rule_type", event.target.value)}>
            {recurrenceTypes.map((type) => (
              <option key={type} value={type}>
                {labelFrom(recurrenceTypeLabels, type)}
              </option>
            ))}
          </select>
        </label>

        <label>
          Дата начала
          <input
            type="date"
            value={value.date_start || ""}
            onChange={(event) => setNestedField(value, onChange, "date_start", event.target.value)}
          />
        </label>

        <label>
          Дата окончания
          <input
            type="date"
            value={value.date_end || ""}
            onChange={(event) => setNestedField(value, onChange, "date_end", event.target.value)}
          />
        </label>

        <label>
          Время выполнения
          <input
            type="time"
            value={value.execution_time || "12:00"}
            onChange={(event) => setNestedField(value, onChange, "execution_time", event.target.value)}
          />
        </label>

        <label>
          Часовой пояс
          <select value={value.timezone || "Europe/Moscow"} onChange={(event) => setNestedField(value, onChange, "timezone", event.target.value)}>
            {timeZoneOptions.map((zone) => (
              <option key={zone} value={zone}>
                {zone}
              </option>
            ))}
          </select>
        </label>

        <label className="recurrence-preview">
          Следующий запуск
          <input type="text" value={computedPreview || "—"} disabled readOnly />
        </label>
      </div>

      {ruleType === "every_n_days" ? (
        <label>
          Интервал в днях
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
            Интервал в месяцах
            <input
              type="number"
              min="1"
              value={value.interval_value || 1}
              onChange={(event) => setNestedField(value, onChange, "interval_value", event.target.value)}
            />
          </label>
          <label>
            День месяца
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
          label="Четность дня"
          rule={value}
          parity={value.day_of_month_parity}
          onChange={onChange}
          fieldKey="day_of_month_parity"
        />
      ) : null}

      {ruleType === "weekday_parity" ? (
        <ParitySelect
          label="Четность дня недели"
          rule={value}
          parity={value.weekday_parity}
          onChange={onChange}
          fieldKey="weekday_parity"
        />
      ) : null}

      {ruleType === "specific_dates" ? (
        <label>
          Конкретные даты
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
