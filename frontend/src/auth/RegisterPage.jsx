import { useState } from "react";
import { Link, Navigate, useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "./AuthContext";
import { AuthPage } from "./AuthPage";
import { PasswordField } from "./PasswordField";

const ROLE_OPTIONS = [
  { value: "doctor", label: "Врач" },
  { value: "nurse", label: "Медсестра" },
];

function readError(error) {
  if (error?.messages?.length) {
    return error.messages.join(", ");
  }

  if (typeof error?.message === "string" && error.message.trim()) {
    return error.message;
  }

  return "Не удалось создать аккаунт";
}

export function RegisterPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [name, setName] = useState("");
  const [lastName, setLastName] = useState("");
  const [role, setRole] = useState("");
  const [localError, setLocalError] = useState("");

  if (auth.user) {
    return <Navigate to="/tasks" replace />;
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setLocalError("");
    auth.setError(null);

    try {
      await auth.register({ email, password, name, last_name: lastName, role });
      navigate(location.state?.from?.pathname || "/tasks", { replace: true });
    } catch (requestError) {
      const message = readError(requestError);
      setLocalError(message);
      auth.setError(message);
    }
  }

  const error = localError || auth.error;

  return (
    <AuthPage
      className="auth-page-register"
      title="Регистрация"
      subtitle="Создайте рабочую учётную запись для задач, календаря и тегов."
    >
      <form className="auth-form auth-form-register" onSubmit={handleSubmit}>
        {error ? <div className="alert error auth-error">{error}</div> : null}
        <div className="auth-grid auth-grid-two">
          <label className="auth-field">
            <span>Email</span>
            <input
              autoComplete="email"
              placeholder="example@medods.com"
              type="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              required
            />
          </label>
          <PasswordField autoComplete="new-password" value={password} onChange={(event) => setPassword(event.target.value)} />
        </div>
        <div className="auth-grid auth-grid-two">
          <label className="auth-field">
            <span>Имя</span>
            <input autoComplete="given-name" value={name} onChange={(event) => setName(event.target.value)} required />
          </label>
          <label className="auth-field">
            <span>Фамилия</span>
            <input autoComplete="family-name" value={lastName} onChange={(event) => setLastName(event.target.value)} required />
          </label>
        </div>
        <label className="auth-field">
          <span>Роль</span>
          <select value={role} onChange={(event) => setRole(event.target.value)} required>
            <option value="">Выберите роль</option>
            {ROLE_OPTIONS.map((option) => (
              <option key={option.value} value={option.value}>
                {option.label}
              </option>
            ))}
          </select>
        </label>
        <button type="submit" className="auth-primary">
          Создать аккаунт
        </button>
        <Link to="/login" className="auth-secondary">
          Войти
        </Link>
      </form>
    </AuthPage>
  );
}
