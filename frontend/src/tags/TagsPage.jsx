import { useEffect, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

function readError(error) {
  if (error?.messages?.length) {
    return error.messages.join(", ");
  }

  if (typeof error?.message === "string" && error.message.trim()) {
    return error.message;
  }

  return "Не удалось загрузить теги";
}

function tagId(tag) {
  return String(tag?.id ?? "");
}

function tagName(tag) {
  return tag?.attributes?.name || tag?.name || "Тег без названия";
}

function tagDescription(tag) {
  return tag?.attributes?.description || tag?.description || "";
}

function tagIsSystem(tag) {
  return Boolean(tag?.attributes?.is_system_tag ?? tag?.is_system_tag);
}

function tagIsInactive(tag) {
  return Boolean(tag?.attributes?.deactivated_at ?? tag?.deactivated_at);
}

export function TagsPage({ api, includeDeactivated = false }) {
  const queryClient = useQueryClient();
  const [createValues, setCreateValues] = useState({ name: "", description: "" });
  const [editValues, setEditValues] = useState({});

  const tagsQuery = useQuery({
    queryKey: ["tags", includeDeactivated],
    queryFn: () => api.tags(includeDeactivated ? { include_deactivated: true } : undefined),
  });

  const tags = tagsQuery.data?.data || [];

  useEffect(() => {
    if (!tagsQuery.data) return;

    setEditValues(
      Object.fromEntries(
        tags.map((tag) => [
          tagId(tag),
          {
            name: tagName(tag),
            description: tagDescription(tag),
          },
        ]),
      ),
    );
  }, [tagsQuery.data, tags]);

  const createMutation = useMutation({
    mutationFn: (tag) => api.createTag(tag),
    onSuccess: async () => {
      setCreateValues({ name: "", description: "" });
      await queryClient.invalidateQueries({ queryKey: ["tags"] });
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, tag }) => api.updateTag(id, tag),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["tags"] });
    },
  });

  const deactivateMutation = useMutation({
    mutationFn: (id) => api.deactivateTag(id),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["tags"] });
    },
  });

  return (
    <section className="stack">
      <header className="page-header">
        <div>
          <p className="eyebrow">Каталог</p>
          <h2>Теги</h2>
        </div>
      </header>

      {tagsQuery.isError ? <div className="alert error">{readError(tagsQuery.error)}</div> : null}

      <form
        className="panel stack"
        onSubmit={(event) => {
          event.preventDefault();
          createMutation.mutate(createValues);
        }}
      >
        <h3>Новый тег</h3>
        <div className="form-grid">
          <label>
            Название
            <input
              value={createValues.name}
              onChange={(event) => setCreateValues((current) => ({ ...current, name: event.target.value }))}
              required
            />
          </label>
          <label>
            Описание
            <input
              value={createValues.description}
              onChange={(event) => setCreateValues((current) => ({ ...current, description: event.target.value }))}
            />
          </label>
        </div>
        {createMutation.isError ? <div className="alert error">{readError(createMutation.error)}</div> : null}
        <button type="submit" disabled={createMutation.isPending}>
          Создать тег
        </button>
      </form>

      <div className="stack">
        {tags.map((tag) => {
          const id = tagId(tag);
          const systemTag = tagIsSystem(tag);
          const inactive = tagIsInactive(tag);
          const draft = editValues[id] || { name: tagName(tag), description: tagDescription(tag) };

          return (
            <article className="table-card" key={id}>
              <div className="stack">
                <div className="row-between">
                  <div>
                    <h3>{tagName(tag)}</h3>
                    <p>{tagDescription(tag) || "Описание не добавлено"}</p>
                  </div>
                  <div className="toolbar">
                    {systemTag ? <span className="status-badge">Системный тег</span> : null}
                    {inactive ? <span className="status-badge">Неактивен</span> : null}
                    <button type="button" disabled={systemTag || inactive} onClick={() => deactivateMutation.mutate(id)}>
                      Деактивировать
                    </button>
                  </div>
                </div>
                <form
                  className="stack"
                  onSubmit={(event) => {
                    event.preventDefault();
                    updateMutation.mutate({ id, tag: draft });
                  }}
                >
                  <div className="form-grid">
                    <label>
                      Название
                      <input
                        value={draft.name}
                        disabled={systemTag || inactive}
                        onChange={(event) =>
                          setEditValues((current) => ({
                            ...current,
                            [id]: { ...draft, name: event.target.value },
                          }))
                        }
                      />
                    </label>
                    <label>
                      Описание
                      <input
                        value={draft.description}
                        disabled={systemTag || inactive}
                        onChange={(event) =>
                          setEditValues((current) => ({
                            ...current,
                            [id]: { ...draft, description: event.target.value },
                          }))
                        }
                      />
                    </label>
                  </div>
                  {updateMutation.isError ? <div className="alert error">{readError(updateMutation.error)}</div> : null}
                  <button type="submit" disabled={systemTag || inactive || updateMutation.isPending}>
                    Сохранить тег
                  </button>
                </form>
              </div>
            </article>
          );
        })}

        {!tagsQuery.isPending && !tags.length ? <div className="page-state">Теги не найдены.</div> : null}
      </div>
    </section>
  );
}
