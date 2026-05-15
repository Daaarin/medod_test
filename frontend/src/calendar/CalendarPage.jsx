import { TaskListPage } from "../tasks/TaskList";

function today() {
  return new Date().toISOString().slice(0, 10);
}

export function CalendarPage({ api }) {
  const current = today();

  return (
    <TaskListPage
      api={api}
      title="Calendar"
      initialFilters={{ from: current, to: current, occurrence_status: "planned" }}
    />
  );
}
