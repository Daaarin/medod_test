import { useQuery } from "@tanstack/react-query";
import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { formatDateTime } from "../utils/display";
import { labelFrom, occurrenceStatusLabels } from "../tasks/taskConstants";

const weekdayLabels = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];

function pad(value) {
  return String(value).padStart(2, "0");
}

function dateKey(date) {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function monthTitle(date) {
  return new Intl.DateTimeFormat("ru-RU", { month: "long", year: "numeric" }).format(date);
}

function monthRange(date) {
  const first = new Date(date.getFullYear(), date.getMonth(), 1);
  const last = new Date(date.getFullYear(), date.getMonth() + 1, 0);
  return { from: dateKey(first), to: dateKey(last) };
}

function startOfCalendar(date) {
  const first = new Date(date.getFullYear(), date.getMonth(), 1);
  const mondayOffset = (first.getDay() + 6) % 7;
  const start = new Date(first);
  start.setDate(first.getDate() - mondayOffset);
  return start;
}

function buildCalendarDays(monthDate) {
  const start = startOfCalendar(monthDate);

  return Array.from({ length: 42 }, (_, index) => {
    const day = new Date(start);
    day.setDate(start.getDate() + index);

    return {
      key: dateKey(day),
      date: day,
      inMonth: day.getMonth() === monthDate.getMonth(),
      isToday: dateKey(day) === dateKey(new Date()),
    };
  });
}

function taskTitle(task) {
  return task?.attributes?.name || "Без названия";
}

function occurrenceFor(task) {
  return task?.attributes?.occurrence ?? null;
}

function occurrenceDate(task) {
  const attributes = task?.attributes ?? {};
  const occurrence = occurrenceFor(task);
  const value = occurrence?.occurs_at || occurrence?.scheduled_at || attributes.next_run_at || attributes.completion_date;
  return value ? String(value).slice(0, 10) : "";
}

function occurrenceTimeValue(task) {
  const occurrence = occurrenceFor(task);
  const value = occurrence?.occurs_at || occurrence?.scheduled_at;
  if (!value) return "";
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return "";

  return parsed.getTime();
}

function occurrenceTimeLabel(task) {
  const occurrence = occurrenceFor(task);
  const value = occurrence?.occurs_at || occurrence?.scheduled_at;
  return value ? formatDateTime(value).split(" ").slice(1).join(" ") : "";
}

function sortTasksByOccurrenceTime(tasks) {
  return [...tasks].sort((left, right) => {
    const leftTime = occurrenceTimeValue(left);
    const rightTime = occurrenceTimeValue(right);
    if (!leftTime && !rightTime) return taskTitle(left).localeCompare(taskTitle(right), "ru");
    if (!leftTime) return 1;
    if (!rightTime) return -1;
    return leftTime - rightTime;
  });
}

function groupByDate(tasks) {
  return tasks.reduce((accumulator, task) => {
    const key = occurrenceDate(task);
    if (!key) return accumulator;

    accumulator[key] = [...(accumulator[key] || []), task];
    return accumulator;
  }, {});
}

function readError(error) {
  if (error?.messages?.length) return error.messages.join(", ");
  if (typeof error?.message === "string" && error.message.trim()) return error.message;
  return "Не удалось загрузить календарь";
}

export function CalendarPage({ api, initialDate = new Date() }) {
  const [visibleMonth, setVisibleMonth] = useState(() => initialDate);
  const [selectedDate, setSelectedDate] = useState(() => dateKey(initialDate));
  const range = useMemo(() => monthRange(visibleMonth), [visibleMonth]);
  const days = useMemo(() => buildCalendarDays(visibleMonth), [visibleMonth]);

  const tasksQuery = useQuery({
    queryKey: ["tasks", "calendar", range],
    queryFn: () => api.tasks({ ...range, occurrence_status: "planned" }),
  });

  const tasks = tasksQuery.data?.data || [];
  const tasksByDate = useMemo(() => groupByDate(tasks), [tasks]);
  const selectedTasks = useMemo(() => sortTasksByOccurrenceTime(tasksByDate[selectedDate] || []), [selectedDate, tasksByDate]);

  function moveMonth(offset) {
    setVisibleMonth((current) => {
      const next = new Date(current.getFullYear(), current.getMonth() + offset, 1);
      const nextKey = dateKey(next);
      setSelectedDate(nextKey);
      return next;
    });
  }

  function goToday() {
    const now = new Date();
    setVisibleMonth(now);
    setSelectedDate(dateKey(now));
  }

  return (
    <section className="stack calendar-page">
      <header className="page-header">
        <div>
          <p className="eyebrow">Календарь задач</p>
          <h2>{monthTitle(visibleMonth)}</h2>
          <p className="header-copy">Плановые выполнения за выбранный месяц.</p>
        </div>
        <div className="calendar-nav" aria-label="Навигация календаря">
          <button type="button" className="ghost-button" onClick={() => moveMonth(-1)}>
            Назад
          </button>
          <button type="button" className="ghost-button" onClick={goToday}>
            Сегодня
          </button>
          <button type="button" className="ghost-button" onClick={() => moveMonth(1)}>
            Вперед
          </button>
        </div>
      </header>

      {tasksQuery.isError ? <div className="alert error">{readError(tasksQuery.error)}</div> : null}

      <div className="calendar-layout">
        <div className="calendar-board" aria-label="Месячный календарь">
          {weekdayLabels.map((label) => (
            <div className="calendar-weekday" key={label}>
              {label}
            </div>
          ))}
          {days.map((day) => {
            const dayTasks = sortTasksByOccurrenceTime(tasksByDate[day.key] || []);
            const active = selectedDate === day.key;
            const hiddenCount = Math.max(0, dayTasks.length - 2);
            return (
              <button
                type="button"
                className={`calendar-day${day.inMonth ? "" : " muted"}${day.isToday ? " today" : ""}${active ? " selected" : ""}`}
                key={day.key}
                onClick={() => setSelectedDate(day.key)}
              >
                <span className="calendar-day-number">{day.date.getDate()}</span>
                <span className="calendar-preview">
                  {dayTasks.slice(0, 2).map((task) => (
                    <span key={task.id}>{taskTitle(task)}</span>
                  ))}
                  {hiddenCount > 0 ? <span className="calendar-preview-more">+{hiddenCount}</span> : null}
                </span>
              </button>
            );
          })}
        </div>

        <aside className="calendar-agenda">
          <p className="eyebrow">
            {new Intl.DateTimeFormat("ru-RU", { day: "numeric", month: "long" }).format(new Date(selectedDate))}
          </p>
          <h3>Задачи дня</h3>
          {tasksQuery.isPending ? <div className="page-state">Загружаем задачи...</div> : null}
          {!tasksQuery.isPending && !selectedTasks.length ? <div className="page-state">На этот день задач нет.</div> : null}
          <div className="stack">
            {selectedTasks.map((task) => {
              const baseTaskId = String(task?.id ?? "").split(":")[0];
              const occurrence = occurrenceFor(task);
              return (
                <Link
                  className="agenda-item"
                  key={task.id}
                  to={`/tasks/${baseTaskId}`}
                  state={occurrence ? { occurrence } : undefined}
                >
                  <span className="agenda-time">{occurrenceTimeLabel(task) || "Весь день"}</span>
                  <strong>{taskTitle(task)}</strong>
                  <span>{labelFrom(occurrenceStatusLabels, occurrence?.status, "Запланировано")}</span>
                </Link>
              );
            })}
          </div>
        </aside>
      </div>
    </section>
  );
}
