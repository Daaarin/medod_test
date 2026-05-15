import { afterEach, describe, expect, it, vi } from "vitest";
import { ApiError, createApiClient } from "./client";

describe("createApiClient", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("attaches bearer tokens and parses JSON responses", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      headers: new Headers({ "content-type": "application/json" }),
      json: async () => ({ data: { id: "1" } }),
    });

    const client = createApiClient({
      baseUrl: "http://api.test",
      getToken: () => "token-123",
      fetchImpl: fetchMock,
    });

    await expect(client.request("/api/v1/tasks")).resolves.toEqual({ data: { id: "1" } });
    expect(fetchMock).toHaveBeenCalledWith(
      "http://api.test/api/v1/tasks",
      expect.objectContaining({
        headers: expect.objectContaining({ Authorization: "Bearer token-123" }),
      }),
    );
  });

  it("normalizes single error responses", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: false,
      status: 400,
      headers: new Headers({ "content-type": "application/json" }),
      json: async () => ({ error: "status is not included in the list" }),
    });

    const client = createApiClient({ baseUrl: "http://api.test", fetchImpl: fetchMock });

    await expect(client.request("/api/v1/tasks?status=bad")).rejects.toMatchObject({
      status: 400,
      messages: ["status is not included in the list"],
    });
  });

  it("normalizes array error responses", async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: false,
      status: 422,
      headers: new Headers({ "content-type": "application/json" }),
      json: async () => ({ errors: ["Name can't be blank"] }),
    });

    const client = createApiClient({ baseUrl: "http://api.test", fetchImpl: fetchMock });

    await expect(client.request("/api/v1/tasks", { method: "POST" })).rejects.toMatchObject({
      status: 422,
      messages: ["Name can't be blank"],
    });
  });
});
