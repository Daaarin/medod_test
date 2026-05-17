import { NavLink, Outlet } from "react-router-dom";
import { useAuth } from "../auth/AuthContext";

const baseLinks = [
  { to: "/tasks", label: "Задачи" },
  { to: "/delegated", label: "Делегированные" },
  { to: "/calendar", label: "Календарь" },
  { to: "/tags", label: "Теги" },
];

function buildDisplayName(user) {
  const parts = [user?.name, user?.last_name].filter(Boolean);
  if (parts.length) {
    return parts.join(" ");
  }

  return user?.email || "Вы вошли";
}

function formatRole(role) {
  if (!role) return "Роль не указана";
  return role === "administrator" ? "Администратор" : role.replaceAll("_", " ");
}

export function Shell() {
  const auth = useAuth();
  const links = auth.isAdmin ? [...baseLinks, { to: "/admin", label: "Администрирование" }] : baseLinks;
  const displayName = buildDisplayName(auth.user);

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="sidebar-header">
          <div className="sidebar-brand">
            <span className="sidebar-brand-mark" aria-hidden="true">
              M
            </span>
            <div>
              <p className="eyebrow">Medods Tasks</p>
              <h1>Задачи</h1>
            </div>
          </div>
          <div className="sidebar-card">
            <div className="sidebar-profile">
              <strong>{displayName}</strong>
              <p className="sidebar-copy">{formatRole(auth.user?.role)}</p>
            </div>
            <p className="sidebar-copy">Оперативное управление задачами, календарем и каталогом тегов.</p>
          </div>
        </div>

        <nav className="tabs" aria-label="Основная навигация">
          {links.map((link) => (
            <NavLink key={link.to} to={link.to} className={({ isActive }) => (isActive ? "active" : undefined)}>
              {link.label}
            </NavLink>
          ))}
        </nav>

        <div className="sidebar-footer">
          <button type="button" className="sidebar-logout" onClick={auth.logout}>
            Выйти
          </button>
        </div>
      </aside>

      <main className="content">
        <Outlet />
      </main>
    </div>
  );
}
