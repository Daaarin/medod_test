import { createContext, useContext, useEffect, useMemo, useState } from "react";
import { clearStoredToken, getStoredToken, storeToken, subscribeToUnauthorized } from "./session";

const AuthContext = createContext(null);

function normalizeMessage(error) {
  if (error?.messages?.length) {
    return error.messages.join(", ");
  }

  if (typeof error?.message === "string" && error.message.trim()) {
    return error.message;
  }

  return "Unable to complete authentication";
}

export function AuthProvider({ api, children }) {
  const [token, setToken] = useState(() => getStoredToken());
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(Boolean(token));
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;

    if (!token) {
      setUser(null);
      setLoading(false);
      return () => {
        cancelled = true;
      };
    }

    setLoading(true);
    api
      .me()
      .then((payload) => {
        if (cancelled) return;

        setUser(payload?.user ?? null);
        setError(null);
      })
      .catch((requestError) => {
        if (cancelled) return;

        if (requestError?.status === 401) {
          clearStoredToken();
          setToken(null);
          setUser(null);
          setError(null);
        } else {
          setError(normalizeMessage(requestError));
        }
      })
      .finally(() => {
        if (!cancelled) {
          setLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [api, token]);

  useEffect(() => {
    const unsubscribe = subscribeToUnauthorized(() => {
      logout();
    });

    return unsubscribe;
  }, []);

  async function login(credentials) {
    setError(null);
    try {
      const payload = await api.login(credentials);
      storeToken(payload.token);
      setToken(payload.token);
      setUser(payload.user ?? null);
      return payload;
    } catch (requestError) {
      const message = normalizeMessage(requestError);
      setError(message);
      throw requestError;
    }
  }

  function logout() {
    clearStoredToken();
    setToken(null);
    setUser(null);
    setError(null);
    setLoading(false);
  }

  const value = useMemo(
    () => ({
      token,
      user,
      loading,
      error,
      setError,
      login,
      logout,
      isAdmin: user?.role === "administrator",
    }),
    [token, user, loading, error],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const value = useContext(AuthContext);
  if (!value) {
    throw new Error("useAuth must be used inside AuthProvider");
  }

  return value;
}
