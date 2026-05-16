export class ApiError extends Error {
  constructor({ status, messages, payload }) {
    super(messages.join(", "));
    this.name = "ApiError";
    this.status = status;
    this.messages = messages;
    this.payload = payload;
  }
}

export const apiBase = import.meta.env.VITE_API_BASE_URL || "http://localhost:3000";

function normalizeMessages(payload, fallback) {
  if (Array.isArray(payload?.errors)) {
    return payload.errors.flatMap((entry) =>
      typeof entry === "string" ? [entry] : [JSON.stringify(entry)],
    );
  }

  if (Array.isArray(payload?.error)) {
    return payload.error.flatMap((entry) =>
      typeof entry === "string" ? [entry] : [JSON.stringify(entry)],
    );
  }

  if (typeof payload?.errors === "string" && payload.errors.trim()) {
    return [payload.errors];
  }

  if (typeof payload?.error === "string" && payload.error.trim()) {
    return [payload.error];
  }

  if (typeof payload === "string" && payload.trim()) {
    return [payload];
  }

  return [fallback];
}

function hasJsonContent(response) {
  return response.headers.get("content-type")?.includes("application/json");
}

async function parsePayload(response) {
  if (response.status === 204) return null;
  if (!hasJsonContent(response)) return response.text();
  return response.json();
}

function joinUrl(baseUrl, path) {
  return `${baseUrl.replace(/\/$/, "")}${path}`;
}

export function createApiClient({
  baseUrl = apiBase,
  getToken,
  onUnauthorized,
  fetchImpl = fetch,
} = {}) {
  async function request(path, options = {}) {
    const token = getToken?.();
    const headers = {
      Accept: "application/json",
      ...(options.body ? { "Content-Type": "application/json" } : {}),
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...options.headers,
    };

    const response = await fetchImpl(joinUrl(baseUrl, path), {
      ...options,
      headers,
    });
    const payload = await parsePayload(response);

    if (!response.ok) {
      if (response.status === 401) {
        onUnauthorized?.();
      }

      throw new ApiError({
        status: response.status,
        payload,
        messages: normalizeMessages(payload, `Request failed with ${response.status}`),
      });
    }

    return payload;
  }

  return { request };
}
