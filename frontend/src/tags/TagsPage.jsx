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
          <p className="header-copy">Быстрое добавление и плотный список тегов для операционной работы.</p>
        </div>
      </header>

      {tagsQuery.isError ? <div className="alert error">{readError(tagsQuery.error)}</div> : null}

      <section className="task-quick-add">
        <form
          className="task-quick-add-form"
          onSubmit={(event) => {
            event.preventDefault();
            createMutation.mutate(createValues);
          }}
        >
          <h3>Quick Add New Tag</h3>
          <input
            placeholder="Название"
            value={createValues.name}
            onChange={(event) => setCreateValues((current) => ({ ...current, name: event.target.value }))}
            required
          />
          <input
            placeholder="Описание"
            value={createValues.description}
            onChange={(event) => setCreateValues((current) => ({ ...current, description: event.target.value }))}
          />
          <button type="submit" disabled={createMutation.isPending}>
            Создать тег
          </button>
        </form>
        {createMutation.isError ? <div className="alert error">{readError(createMutation.error)}</div> : null}
      </section>

      {updateMutation.isError ? <div className="alert error">{readError(updateMutation.error)}</div> : null}
      {deactivateMutation.isError ? <div className="alert error">{readError(deactivateMutation.error)}</div> : null}

      <section className="tag-catalog">
        {!tagsQuery.isPending && !tags.length ? <div className="page-state">Теги не найдены.</div> : null}
        {tags.length ? (
          <table className="tag-table" aria-label="Теги">
            <thead>
              <tr>
                <th>Тег</th>
                <th>Описание</th>
                <th>Статус</th>
                <th>Действия</th>
              </tr>
            </thead>
            <tbody>
              {tags.map((tag) => {
                const id = tagId(tag);
                const systemTag = tagIsSystem(tag);
                const inactive = tagIsInactive(tag);
                const draft = editValues[id] || { name: tagName(tag), description: tagDescription(tag) };
                const locked = systemTag || inactive;

                return (
                  <tr key={id}>
                    <td className="tag-name-cell">
                      <input
                        value={draft.name}
                        disabled={locked}
                        onChange={(event) =>
                          setEditValues((current) => ({
                            ...current,
                            [id]: { ...draft, name: event.target.value },
                          }))
                        }
                      />
                    </td>
                    <td className="tag-description-cell">
                      <input
                        value={draft.description}
                        disabled={locked}
                        onChange={(event) =>
                          setEditValues((current) => ({
                            ...current,
                            [id]: { ...draft, description: event.target.value },
                          }))
                        }
                      />
                    </td>
                    <td>
                      <div className="tag-status-stack">
                        {systemTag ? <span className="status-badge neutral">Системный тег</span> : null}
                        {inactive ? <span className="status-badge warning">Неактивен</span> : null}
                        {!systemTag && !inactive ? <span className="status-badge success">Активен</span> : null}
                      </div>
                    </td>
                    <td className="tag-actions-cell">
                      <div className="toolbar">
                        <button
                          type="button"
                          disabled={locked || updateMutation.isPending}
                          onClick={() => updateMutation.mutate({ id, tag: draft })}
                        >
                          Сохранить
                        </button>
                        <button
                          type="button"
                          disabled={locked || deactivateMutation.isPending}
                          onClick={() => deactivateMutation.mutate(id)}
                        >
                          Деактивировать
                        </button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        ) : null}
      </section>
    </section>
  );
}
