import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { TagsPage } from "./TagsPage";

describe("TagsPage", () => {
  it("disables actions for system tags", async () => {
    const api = {
      tags: vi.fn().mockResolvedValue({
        data: [
          {
            id: "1",
            type: "tag",
            attributes: {
              name: "Отчётность",
              description: "",
              is_system_tag: true,
            },
          },
        ],
      }),
    };
    const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });

    render(
      <QueryClientProvider client={queryClient}>
        <TagsPage api={api} />
      </QueryClientProvider>,
    );

    expect(await screen.findByText("Отчётность")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Деактивировать" })).toBeDisabled();
    expect(screen.getByRole("button", { name: "Сохранить тег" })).toBeDisabled();
  });
});
