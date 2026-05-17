export const taskStatuses = ["", "draft", "pending_acceptance", "ongoing", "completed", "cancelled"];
export const taskScopes = ["", "mine", "delegated_to_me", "created_by_me"];
export const occurrenceStatuses = ["", "planned", "postponed", "executed", "skipped", "superseded", "cancelled"];
export const taskKinds = ["one_time", "recurring"];
export const recurrenceTypes = [
  "every_n_days",
  "every_n_months",
  "specific_dates",
  "day_of_month_parity",
  "every_n_years",
  "weekday_parity",
];

export const statusLabels = {
  "": "Любой",
  draft: "Черновик",
  pending_acceptance: "Ждет принятия",
  ongoing: "В работе",
  completed: "Завершена",
  cancelled: "Отменена",
};

export const scopeLabels = {
  "": "Все доступные",
  mine: "Мои задачи",
  delegated_to_me: "Делегированы мне",
  created_by_me: "Созданы мной",
};

export const occurrenceStatusLabels = {
  "": "Любой",
  planned: "Запланировано",
  postponed: "Перенесено",
  executed: "Выполнено",
  skipped: "Пропущено",
  superseded: "Заменено",
  cancelled: "Отменено",
};

export const taskKindLabels = {
  one_time: "Разовая",
  recurring: "Регулярная",
};

export const recurrenceTypeLabels = {
  every_n_days: "Каждые N дней",
  every_n_months: "Каждые N месяцев",
  specific_dates: "Конкретные даты",
  day_of_month_parity: "По четности дня месяца",
  every_n_years: "Каждые N лет",
  weekday_parity: "По четности дня недели",
};

export const parityLabels = {
  even: "Четные",
  odd: "Нечетные",
};

export function labelFrom(map, value, fallback = "Не указано") {
  if (value === undefined || value === null || value === "") {
    return map?.[""] || fallback;
  }

  return map?.[value] || String(value).replaceAll("_", " ");
}
