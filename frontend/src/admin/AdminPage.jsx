import { useQuery } from "@tanstack/react-query";
import { apiBase } from "../api/client";
import { TagsPage } from "../tags/TagsPage";
import { TaskListPage } from "../tasks/TaskList";

function readError(error) {
  if (error?.messages?.length) {
    return error.messages.join(", ");
  }

  if (typeof error?.message === "string" && error.message.trim()) {
    return error.message;
  }

  return "Не удалось проверить состояние API";
}

export function AdminPage({ api }) {
  const swaggerUrl = new URL("/api-docs", apiBase).toString();
  const healthQuery = useQuery({
    queryKey: ["health"],
    queryFn: () => api.health(),
    retry: false,
  });

  return (
    <section className="stack">
      <header className="page-header">
        <div>
          <p className="eyebrow">Администратор</p>
          <h2>Администрирование</h2>
          <p className="header-copy">Контроль доступности API и быстрый переход к документации.</p>
        </div>
        <a className="page-action" href={swaggerUrl} target="_blank" rel="noreferrer">
          Открыть Swagger
        </a>
      </header>

      <div className="panel">
        <h3>Состояние API</h3>
        {healthQuery.isPending ? <div className="page-state">Проверяем API...</div> : null}
        {healthQuery.isError ? <div className="alert error">{readError(healthQuery.error)}</div> : null}
        {!healthQuery.isPending && !healthQuery.isError ? <div>Доступен</div> : null}
      </div>

      <TaskListPage api={api} title="Все доступные задачи" showScope={false} hiddenFilters={["status"]} defaultFromToday={false} />
      <TagsPage api={api} includeDeactivated />
    </section>
  );
}
