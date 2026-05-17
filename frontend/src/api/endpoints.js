function queryString(params = {}) {
  const search = new URLSearchParams();

  Object.entries(params).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== "") {
      search.set(key, value);
    }
  });

  const value = search.toString();
  return value ? `?${value}` : "";
}

function jsonBody(body) {
  return JSON.stringify(body);
}

export function createEndpoints(client) {
  return {
    login: (credentials) =>
      client.request("/api/v1/auth/login", {
        method: "POST",
        body: jsonBody(credentials),
      }),
    register: (credentials) =>
      client.request("/api/v1/auth/register", {
        method: "POST",
        body: jsonBody(credentials),
      }),
    me: () => client.request("/api/v1/auth/me"),
    users: () => client.request("/api/v1/users"),
    health: () => client.request("/up"),
    tasks: (params) => client.request(`/api/v1/tasks${queryString(params)}`),
    task: (id) => client.request(`/api/v1/tasks/${id}`),
    createTask: (task) =>
      client.request("/api/v1/tasks", {
        method: "POST",
        body: jsonBody({ task }),
      }),
    updateTask: (id, task) =>
      client.request(`/api/v1/tasks/${id}`, {
        method: "PATCH",
        body: jsonBody({ task }),
      }),
    deactivateTask: (id) => client.request(`/api/v1/tasks/${id}`, { method: "DELETE" }),
    acceptTask: (taskId) => client.request(`/api/v1/tasks/${taskId}/accept`, { method: "POST" }),
    declineTask: (taskId) => client.request(`/api/v1/tasks/${taskId}/decline`, { method: "POST" }),
    tags: (params) => client.request(`/api/v1/tags${queryString(params)}`),
    createTag: (tag) =>
      client.request("/api/v1/tags", {
        method: "POST",
        body: jsonBody({ tag }),
      }),
    updateTag: (id, tag) =>
      client.request(`/api/v1/tags/${id}`, {
        method: "PATCH",
        body: jsonBody({ tag }),
      }),
    deactivateTag: (id) => client.request(`/api/v1/tags/${id}`, { method: "DELETE" }),
    attachTag: (taskId, tagId) => client.request(`/api/v1/tasks/${taskId}/tags/${tagId}`, { method: "POST" }),
    detachTag: (taskId, tagId) => client.request(`/api/v1/tasks/${taskId}/tags/${tagId}`, { method: "DELETE" }),
    postponeOccurrence: (id, postponedTo) =>
      client.request(`/api/v1/task_occurrences/${id}/postpone`, {
        method: "POST",
        body: jsonBody({ postponed_to: postponedTo }),
      }),
    executeOccurrence: (id) => client.request(`/api/v1/task_occurrences/${id}/execute`, { method: "POST" }),
    skipOccurrence: (id, skipReason) =>
      client.request(`/api/v1/task_occurrences/${id}/skip`, {
        method: "POST",
        body: jsonBody({ skip_reason: skipReason }),
      }),
  };
}
