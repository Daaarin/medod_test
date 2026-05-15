import { TaskListPage } from "../tasks/TaskList";

function today() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");

  return `${year}-${month}-${day}`;
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
