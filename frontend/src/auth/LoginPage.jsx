import { useState } from "react";
import { Navigate, useLocation, useNavigate } from "react-router-dom";
import { useAuth } from "./AuthContext";

function readError(error) {
  if (error?.messages?.length) {
    return error.messages.join(", ");
  }

  if (typeof error?.message === "string" && error.message.trim()) {
    return error.message;
  }

  return "Unable to sign in";
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
    <main className="login-page">
      <form className="auth-card" onSubmit={handleSubmit}>
        <p className="eyebrow">Medods Tasks</p>
        <h1>Sign in</h1>
        {error ? <div className="alert error">{error}</div> : null}
        <label>
          Email
          <input
            autoComplete="email"
            type="email"
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            required
          />
        </label>
        <label>
          Password
          <input
            autoComplete="current-password"
            type="password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            required
          />
        </label>
        <button type="submit">Sign in</button>
      </form>
    </main>
  );
}
