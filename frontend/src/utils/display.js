const ROLE_LABELS = {
  administrator: "Администратор",
  doctor: "Врач",
  nurse: "Медсестра",
};

function normalizeDateInput(value) {
  if (!value) return "";

  const text = String(value);
  const dateMatch = text.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (dateMatch) {
    return dateMatch.slice(1);
  }

  const parsed = new Date(text);
  if (Number.isNaN(parsed.getTime())) return "";

  return [ parsed.getFullYear(), String(parsed.getMonth() + 1).padStart(2, "0"), String(parsed.getDate()).padStart(2, "0") ];
}

function parseDateParts(value) {
  const parts = normalizeDateInput(value);
  if (!parts.length) return null;

  const [ year, month, day ] = parts.map(Number);
  return { year, month, day, text: `${parts[2]}-${parts[1]}-${parts[0]}` };
}

function parseTimeParts(value) {
  if (!value) return null;

  const text = String(value);
  const match = text.match(/T(\d{2}):(\d{2})(?::(\d{2}))?/);
  if (!match) return null;

  return {
    hour: match[1],
    minute: match[2],
    second: match[3] || "00"
  };
}

function parseOffsetLabel(value) {
  if (!value) return "UTC +0";

  const text = String(value);
  const offsetMatch = text.match(/([+-])(\d{2}):(\d{2})$/);
  if (offsetMatch) {
    const sign = offsetMatch[1] === "-" ? "-" : "+";
    const hours = String(Number(offsetMatch[2]));
    const minutes = Number(offsetMatch[3]);
    return minutes ? `UTC ${sign}${hours}:${offsetMatch[3]}` : `UTC ${sign}${hours}`;
  }

  if (text.endsWith("Z")) {
    return "UTC +0";
  }

  return "UTC +0";
}

function formatDateParts(parts) {
  return parts ? `${String(parts.day).padStart(2, "0")}-${String(parts.month).padStart(2, "0")}-${parts.year}` : "—";
}

export function formatDate(value) {
  const parts = parseDateParts(value);
  if (parts) return formatDateParts(parts);

  return "—";
}

export function formatTime(value) {
  const timeParts = parseTimeParts(value);
  if (timeParts) {
    return `${timeParts.hour}:${timeParts.minute} (${parseOffsetLabel(value)})`;
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return "—";

  const time = new Intl.DateTimeFormat("ru-RU", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(parsed);
  return `${time} (${parseOffsetLabel(value)})`;
}

export function formatDateTime(value) {
  const dateParts = parseDateParts(value);
  const timeParts = parseTimeParts(value);

  if (dateParts && timeParts) {
    return `${formatDateParts(dateParts)} ${timeParts.hour}:${timeParts.minute} (${parseOffsetLabel(value)})`;
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return "—";

  return new Intl.DateTimeFormat("ru-RU", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(parsed);
}

export function todayIsoDate(now = new Date()) {
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function formatUserLabel(user, { includeId = false } = {}) {
  if (!user) return "—";

  const source = user.attributes ? { id: user.id, ...user.attributes } : user;
  const baseLabel =
    source.display_name || [ROLE_LABELS[source.role] || source.role, source.last_name, source.name].filter(Boolean).join(" ");
  if (!includeId) return baseLabel || "—";

  return source.id ? `${baseLabel} (${source.id})` : baseLabel || "—";
}

function fallbackTimeZones() {
  return [ "Europe/Moscow", "UTC", "Europe/Berlin", "Europe/London", "Asia/Yekaterinburg", "Asia/Novosibirsk" ];
}

export function getTimeZoneOptions() {
  const supported = typeof Intl.supportedValuesOf === "function" ? Intl.supportedValuesOf("timeZone") : fallbackTimeZones();
  return [ "Europe/Moscow", ...new Set([ ...supported, ...fallbackTimeZones() ]) ].filter((zone, index, list) => list.indexOf(zone) === index);
}

function utcOffsetLabelForTimeZone(timeZone, referenceDate) {
  try {
    const formatter = new Intl.DateTimeFormat("en-US", {
      timeZone,
      hour: "2-digit",
      hour12: false,
      timeZoneName: "shortOffset",
    });
    const parts = formatter.formatToParts(referenceDate);
    const timeZoneName = parts.find((part) => part.type === "timeZoneName")?.value || "GMT";
    return timeZoneName.replace("GMT", "UTC ");
  } catch {
    return "UTC +0";
  }
}

function recurrenceDateKey(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}

function fromDateKey(dateKey) {
  const [ year, month, day ] = dateKey.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day));
}

function clampDay(year, month, day) {
  return Math.min(day, new Date(Date.UTC(year, month, 0)).getUTCDate());
}

function addMonths(dateKey, monthOffset, chosenDay) {
  const [ year, month ] = dateKey.split("-").map(Number);
  const totalMonths = year * 12 + (month - 1) + monthOffset;
  const nextYear = Math.floor(totalMonths / 12);
  const nextMonth = (totalMonths % 12) + 1;
  const nextDay = clampDay(nextYear, nextMonth, chosenDay);
  return new Date(Date.UTC(nextYear, nextMonth - 1, nextDay));
}

function addYears(dateKey, yearOffset, chosenMonth, chosenDay) {
  const [ year ] = dateKey.split("-").map(Number);
  const nextYear = year + yearOffset;
  const nextMonth = chosenMonth;
  const nextDay = clampDay(nextYear, nextMonth, chosenDay);
  return new Date(Date.UTC(nextYear, nextMonth - 1, nextDay));
}

function formatTimeOnly(executionTime, timeZone, candidateDate) {
  return `${executionTime} (${utcOffsetLabelForTimeZone(timeZone, candidateDate)})`;
}

function nextSpecificDate(recurrence) {
  const runDates = (recurrence.specific_dates || "")
    .split(",")
    .map((date) => date.trim())
    .filter(Boolean)
    .sort();

  const startKey = recurrence.date_start || "";
  return runDates.find((date) => date >= startKey) || "";
}

function nextParityDate(recurrence, matcher) {
  if (!recurrence.date_start) return "";

  let candidate = fromDateKey(recurrence.date_start);
  for (let guard = 0; guard < 3700; guard += 1) {
    if (matcher(candidate)) {
      return recurrenceDateKey(candidate);
    }

    candidate = new Date(candidate);
    candidate.setUTCDate(candidate.getUTCDate() + 1);
  }

  return "";
}

export function computeRecurringNextRunDate(recurrence) {
  if (!recurrence?.rule_type || !recurrence.date_start || !recurrence.execution_time) {
    return "";
  }

  const startKey = recurrence.date_start;
  let candidateDate = startKey;

  switch (recurrence.rule_type) {
    case "every_n_days":
      candidateDate = startKey;
      break;
    case "every_n_months": {
      const chosenDay = Number(recurrence.day_of_month || fromDateKey(startKey).getUTCDate());
      let period = 0;
      let candidate = addMonths(startKey, period, chosenDay);
      while (recurrenceDateKey(candidate) < startKey) {
        period += 1;
        candidate = addMonths(startKey, period, chosenDay);
      }
      candidateDate = recurrenceDateKey(candidate);
      break;
    }
    case "every_n_years": {
      const chosenMonth = Number(recurrence.month_of_year || fromDateKey(startKey).getUTCMonth() + 1);
      const chosenDay = Number(recurrence.day_of_month || fromDateKey(startKey).getUTCDate());
      let period = 0;
      let candidate = addYears(startKey, period, chosenMonth, chosenDay);
      while (recurrenceDateKey(candidate) < startKey) {
        period += 1;
        candidate = addYears(startKey, period, chosenMonth, chosenDay);
      }
      candidateDate = recurrenceDateKey(candidate);
      break;
    }
    case "day_of_month_parity":
      candidateDate = nextParityDate(recurrence, (date) => (recurrence.day_of_month_parity || "even") === "even" ? date.getUTCDate() % 2 === 0 : date.getUTCDate() % 2 === 1);
      break;
    case "weekday_parity":
      candidateDate = nextParityDate(recurrence, (date) => {
        const isoWeekday = ((date.getUTCDay() + 6) % 7) + 1;
        return (recurrence.weekday_parity || "even") === "even" ? isoWeekday % 2 === 0 : isoWeekday % 2 === 1;
      });
      break;
    case "specific_dates":
      candidateDate = nextSpecificDate(recurrence);
      break;
    default:
      return "";
  }

  return candidateDate || "";
}

export function computeRecurringNextRunPreview(recurrence) {
  const candidateDate = computeRecurringNextRunDate(recurrence);
  if (!candidateDate) return "";

  const timeZone = recurrence.timezone || "Europe/Moscow";

  const candidate = fromDateKey(candidateDate);
  return `${formatDate(candidateDate)} ${formatTimeOnly(recurrence.execution_time, timeZone, candidate)}`;
}

export function datePartFromDateTimeInput(value) {
  return String(value || "").slice(0, 10);
}
