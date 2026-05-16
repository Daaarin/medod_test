import { useQuery } from "@tanstack/react-query";
import { TagsPage } from "../tags/TagsPage";
import { TaskListPage } from "../tasks/TaskList";

function readError(error) {
  if (error?.messages?.length) {
    return error.messages.join(", ");
  }

  if (typeof error?.message === "string" && error.message.trim()) {
    return error.message;
  }

  return "Unable to load health status";
}

export function AdminPage({ api }) {
  const healthQuery = useQuery({
    queryKey: ["health"],
    queryFn: () => api.health(),
    retry: false,
  });

  return (
    <section className="stack">
      <header className="page-header">
        <div>
          <p className="eyebrow">Administrator</p>
          <h2>Admin</h2>
        </div>
        <a className="page-action" href="/api-docs" target="_blank" rel="noreferrer">
          Open Swagger
        </a>
      </header>

      <div className="panel">
        <h3>API health</h3>
        {healthQuery.isPending ? <div className="page-state">Checking API health...</div> : null}
        {healthQuery.isError ? <div className="alert error">{readError(healthQuery.error)}</div> : null}
        {!healthQuery.isPending && !healthQuery.isError ? <div>Available</div> : null}
      </div>

      <TaskListPage api={api} title="All visible tasks" showScope={false} hiddenFilters={["status"]} />
      <TagsPage api={api} includeDeactivated />
    </section>
  );
}
