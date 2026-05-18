import { useState } from "react";
import { Link, Navigate, useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "./AuthContext";
import { AuthPage } from "./AuthPage";
import { PasswordField } from "./PasswordField";

function readError(error) {
  if (error?.messages?.length) {
    return error.messages.join(", ");
  }

  if (typeof error?.message === "string" && error.message.trim()) {
    return error.message;
  }

  return "Не удалось войти";
}

export function LoginPage() {
  const auth = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [localError, setLocalError] = useState("");

  if (auth.user) {
    return <Navigate to="/tasks" replace />;
  }

  async function handleSubmit(event) {
    event.preventDefault();
    setLocalError("");
    auth.setError(null);

    try {
      await auth.login({ email, password });
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
      className="auth-page-login"
      title="Вход"
      subtitle="Рабочее пространство для задач, календаря и тегов."
    >
      <form className="auth-form auth-form-login" onSubmit={handleSubmit}>
        {error ? <div className="alert error auth-error">{error}</div> : null}
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
        <PasswordField value={password} onChange={(event) => setPassword(event.target.value)} />
        <button type="submit" className="auth-primary">
          Войти
        </button>
        <Link to="/register" className="auth-secondary">
          Создать аккаунт
        </Link>
      </form>
    </AuthPage>
  );
}
