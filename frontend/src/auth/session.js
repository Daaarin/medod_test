const TOKEN_KEY = "medods.authToken";
const unauthorizedListeners = new Set();

export function getStoredToken() {
  return window.localStorage.getItem(TOKEN_KEY);
}

export function storeToken(token) {
  window.localStorage.setItem(TOKEN_KEY, token);
}

export function clearStoredToken() {
  window.localStorage.removeItem(TOKEN_KEY);
}

export function notifyUnauthorized() {
  unauthorizedListeners.forEach((listener) => {
    listener();
  });
}

export function subscribeToUnauthorized(listener) {
  unauthorizedListeners.add(listener);

  return () => {
    unauthorizedListeners.delete(listener);
  };
}
