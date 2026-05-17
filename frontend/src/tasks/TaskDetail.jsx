import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate, useParams } from "react-router-dom";
import { labelFrom, occurrenceStatusLabels, statusLabels, taskKindLabels } from "./taskConstants";

function readError(error) {
  if (error?.messages?.length) {
    return error.messages.join(", ");
  }

  if (typeof error?.message === "string" && error.message.trim()) {
    return error.message;
  }

  return "Не удалось загрузить задачу";
}

function displayValue(value) {
  return value ?? "—";
}

function toDateInput(value) {
  if (!value) return "";
  return String(value).slice(0, 10);
}

function toDateTimeInput(value) {
  if (!value) return "";
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return "";
  const year = parsed.getFullYear();
  const month = String(parsed.getMonth() + 1).padStart(2, "0");
  const day = String(parsed.getDate()).padStart(2, "0");
  const hours = String(parsed.getHours()).padStart(2, "0");
  const minutes = String(parsed.getMinutes()).padStart(2, "0");
  return `${year}-${month}-${day}T${hours}:${minutes}`;
}

function localDateTimeToIso(value) {
  if (!value) return "";
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? value : parsed.toISOString();
}

function mutationError(error) {
  return readError(error);
}

function emptyEditState(attributes) {
  return {
    name: attributes?.name || "",
    description: attributes?.description || "",
    completion_date: toDateInput(attributes?.completion_date),
  };
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

function taskTags(attributes) {
  return Array.isArray(attributes?.tags) ? attributes.tags : [];
}

function normalizeOccurrence(occurrence) {
  if (!occurrence) return null;

  if (occurrence.attributes) {
    return {
      id: occurrence.id,
      ...occurrence.attributes,
    };
  }

  return occurrence;
}

function occurrenceFromPayload(payload) {
  return normalizeOccurrence(payload?.data?.occurrence ?? payload?.data?.attributes?.occurrence ?? null);
}

export function TaskDetail({ api }) {
  const { taskId } = useParams();
  const location = useLocation();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [occurrence, setOccurrence] = useState(() => location.state?.occurrence || null);
  const [editValues, setEditValues] = useState(() => emptyEditState());
  const [postponedTo, setPostponedTo] = useState("");
  const [skipReason, setSkipReason] = useState("");
  const [selectedTagId, setSelectedTagId] = useState("");
  const [feedback, setFeedback] = useState("");

  const taskQuery = useQuery({
    queryKey: ["task", taskId],
    queryFn: () => api.task(taskId),
  });
  const tagsQuery = useQuery({
    queryKey: ["tags"],
    queryFn: () => api.tags(),
  });

  const task = taskQuery.data?.data;
  const attributes = task?.attributes || {};
  const taskOccurrence = normalizeOccurrence(attributes.occurrence);
  const attachedTags = taskTags(attributes);
  const attachedTagIds = new Set(attachedTags.map((tag) => tagId(tag)));
  const availableTags = (tagsQuery.data?.data || []).filter((tag) => !attachedTagIds.has(tagId(tag)));

  useEffect(() => {
    if (task?.attributes) {
      setEditValues(emptyEditState(attributes));
      setPostponedTo(toDateTimeInput((taskOccurrence || occurrence)?.scheduled_at || (taskOccurrence || occurrence)?.occurs_at || ""));
      setSkipReason("");
    }
  }, [attributes, occurrence, task, taskOccurrence]);

  useEffect(() => {
    if (taskOccurrence) {
      setOccurrence(taskOccurrence);
    }
  }, [taskOccurrence]);

  useEffect(() => {
    if (!availableTags.length) {
      if (selectedTagId) {
        setSelectedTagId("");
      }
      return;
    }

    const selectedStillAvailable = availableTags.some((tag) => tagId(tag) === selectedTagId);
    if (!selectedTagId || !selectedStillAvailable) {
      setSelectedTagId(tagId(availableTags[0]));
    }
  }, [availableTags, selectedTagId]);

  const invalidateTaskData = async () => {
    await queryClient.invalidateQueries({ queryKey: ["task", taskId] });
    await queryClient.invalidateQueries({ queryKey: ["tasks"] });
    await queryClient.invalidateQueries({ queryKey: ["tags"] });
  };

  const updateMutation = useMutation({
    mutationFn: () =>
      api.updateTask(taskId, {
        name: editValues.name,
        description: editValues.description,
        completion_date: editValues.completion_date ? editValues.completion_date : null,
      }),
    onSuccess: async () => {
      setFeedback("Задача сохранена.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const acceptMutation = useMutation({
    mutationFn: () => api.acceptTask(taskId),
    onSuccess: async () => {
      setFeedback("Задача принята.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const declineMutation = useMutation({
    mutationFn: () => api.declineTask(taskId),
    onSuccess: async () => {
      setFeedback("Задача отклонена.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const deactivateMutation = useMutation({
    mutationFn: () => api.deactivateTask(taskId),
    onSuccess: async () => {
      setFeedback("Задача деактивирована.");
      await invalidateTaskData();
      navigate("/tasks", { replace: true });
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const postponeMutation = useMutation({
    mutationFn: () => api.postponeOccurrence(occurrence.id, localDateTimeToIso(postponedTo)),
    onSuccess: async (data) => {
      const nextOccurrence = occurrenceFromPayload(data);
      if (nextOccurrence) {
        setOccurrence(nextOccurrence);
      }
      setFeedback("Выполнение перенесено.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const executeMutation = useMutation({
    mutationFn: () => api.executeOccurrence(occurrence.id),
    onSuccess: async (data) => {
      const nextOccurrence = occurrenceFromPayload(data);
      if (nextOccurrence) {
        setOccurrence(nextOccurrence);
      }
      setFeedback("Выполнение отмечено.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const skipMutation = useMutation({
    mutationFn: () => api.skipOccurrence(occurrence.id, skipReason || undefined),
    onSuccess: async (data) => {
      const nextOccurrence = occurrenceFromPayload(data);
      if (nextOccurrence) {
        setOccurrence(nextOccurrence);
      }
      setFeedback("Выполнение пропущено.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const attachMutation = useMutation({
    mutationFn: () => api.attachTag(taskId, selectedTagId),
    onSuccess: async () => {
      setFeedback("Тег добавлен.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const detachMutation = useMutation({
    mutationFn: (tagIdentifier) => api.detachTag(taskId, tagIdentifier),
    onSuccess: async () => {
      setFeedback("Тег снят.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const canShowOccurrenceActions =
    Boolean(occurrence?.id) && !occurrence?.projected && ["planned", "postponed"].includes(occurrence?.status);

  const summaryItems = useMemo(
    () => [
      ["Статус", labelFrom(statusLabels, attributes.status, "—")],
      ["Тип", labelFrom(taskKindLabels, attributes.task_kind, "—")],
      ["Автор", attributes.creator_id],
      ["Ответственный", attributes.responsible_id],
      ["Делегировано", attributes.delegated_user_id],
      ["Дата завершения", attributes.completion_date],
      ["Первый запуск", attributes.first_run_at],
      ["Следующий запуск", attributes.next_run_at],
      ["Принята", attributes.accepted_at],
      ["Отменена", attributes.cancelled_at],
      ["Причина завершения", attributes.end_reason],
      ["Причина отмены", attributes.cancellation_reason],
    ],
    [attributes],
  );

  if (taskQuery.isPending) {
    return <div className="page-state">Загружаем задачу...</div>;
  }

  if (taskQuery.isError) {
    return <div className="alert error">{readError(taskQuery.error)}</div>;
  }

  return (
    <section className="stack detail-page">
      <header className="detail-topbar">
        <div>
          <p className="eyebrow">Задача</p>
          <h2>{attributes.name || "Без названия"}</h2>
          <p className="header-copy">{attributes.description || "Описание не добавлено"}</p>
        </div>
        <div className="detail-actions">
          <button
            type="button"
            onClick={() => acceptMutation.mutate()}
            disabled={attributes.status !== "pending_acceptance" || acceptMutation.isPending}
          >
            Принять
          </button>
          <button
            type="button"
            onClick={() => declineMutation.mutate()}
            disabled={attributes.status !== "pending_acceptance" || declineMutation.isPending}
          >
            Отклонить
          </button>
          <button
            type="button"
            onClick={() => deactivateMutation.mutate()}
            disabled={["completed", "cancelled"].includes(attributes.status) || deactivateMutation.isPending}
          >
            Деактивировать
          </button>
        </div>
      </header>

      {feedback ? <div className="alert">{feedback}</div> : null}

      <div className="detail-layout">
        <div className="detail-column">
          <section className="detail-panel">
            <h3>Основная информация</h3>
            <form
              className="stack"
              onSubmit={(event) => {
                event.preventDefault();
                updateMutation.mutate();
              }}
            >
              <div className="form-grid">
                <label>
                  Название
                  <input
                    value={editValues.name}
                    onChange={(event) => setEditValues((current) => ({ ...current, name: event.target.value }))}
                  />
                </label>
                <label>
                  Дата завершения
                  <input
                    type="date"
                    value={editValues.completion_date}
                    onChange={(event) =>
                      setEditValues((current) => ({ ...current, completion_date: event.target.value }))
                    }
                  />
                </label>
              </div>
              <label>
                Описание
                <textarea
                  value={editValues.description}
                  onChange={(event) => setEditValues((current) => ({ ...current, description: event.target.value }))}
                />
              </label>
              {updateMutation.isError ? <div className="alert error">{mutationError(updateMutation.error)}</div> : null}
              <button type="submit" disabled={updateMutation.isPending}>
                Сохранить
              </button>
            </form>
          </section>

          <section className="detail-panel stack">
            <h3>Теги</h3>
            {tagsQuery.isPending ? <div className="page-state">Загружаем теги...</div> : null}
            {tagsQuery.isError ? <div className="alert error">{readError(tagsQuery.error)}</div> : null}
            {attachedTags.length ? (
              <div className="detail-inline-grid">
                {attachedTags.map((tag) => (
                  <div className="row-between" key={tagId(tag)}>
                    <div>
                      <strong>{tagName(tag)}</strong>
                      {tagDescription(tag) ? <p className="muted-line">{tagDescription(tag)}</p> : null}
                    </div>
                    <button
                      type="button"
                      onClick={() => detachMutation.mutate(tagId(tag))}
                      disabled={detachMutation.isPending}
                    >
                      Снять
                    </button>
                  </div>
                ))}
              </div>
            ) : (
              <div className="page-state">У задачи пока нет тегов.</div>
            )}
            {!tagsQuery.isPending && availableTags.length ? (
              <div className="toolbar">
                <label>
                  Добавить тег
                  <select value={selectedTagId} onChange={(event) => setSelectedTagId(event.target.value)}>
                    {availableTags.map((tag) => (
                      <option key={tagId(tag)} value={tagId(tag)}>
                        {tagName(tag)}
                      </option>
                    ))}
                  </select>
                </label>
                <button
                  type="button"
                  onClick={() => attachMutation.mutate()}
                  disabled={!selectedTagId || attachMutation.isPending}
                >
                  Добавить
                </button>
              </div>
            ) : null}
            {attachMutation.isError ? <div className="alert error">{mutationError(attachMutation.error)}</div> : null}
            {detachMutation.isError ? <div className="alert error">{mutationError(detachMutation.error)}</div> : null}
          </section>
        </div>

        <div className="detail-column">
          <section className="detail-summary-card">
            <h3>Детали задачи</h3>
            <dl className="detail-summary-table">
              {summaryItems.map(([label, value]) => (
                <div key={label}>
                  <dt>{label}</dt>
                  <dd>{displayValue(value)}</dd>
                </div>
              ))}
            </dl>
          </section>

          {occurrence ? (
            <section className="detail-panel stack">
              <h3>Временная шкала / Статистика</h3>
              <dl className="detail-summary-table">
                <div>
                  <dt>Статус</dt>
                  <dd>{labelFrom(occurrenceStatusLabels, occurrence.status, "—")}</dd>
                </div>
                <div>
                  <dt>Запланировано</dt>
                  <dd>{displayValue(occurrence.scheduled_at)}</dd>
                </div>
                <div>
                  <dt>Фактически</dt>
                  <dd>{displayValue(occurrence.actual_at)}</dd>
                </div>
                <div>
                  <dt>Перенесено на</dt>
                  <dd>{displayValue(occurrence.postponed_to)}</dd>
                </div>
                <div>
                  <dt>Причина пропуска</dt>
                  <dd>{displayValue(occurrence.skip_reason)}</dd>
                </div>
                <div>
                  <dt>Сгенерировано</dt>
                  <dd>{displayValue(occurrence.generated_at)}</dd>
                </div>
              </dl>

              {canShowOccurrenceActions ? (
                <div className="detail-actions-stack">
                  <label>
                    Перенести на
                    <input
                      type="datetime-local"
                      value={postponedTo}
                      onChange={(event) => setPostponedTo(event.target.value)}
                    />
                  </label>
                  <div className="toolbar">
                    <button
                      type="button"
                      onClick={() => postponeMutation.mutate()}
                      disabled={postponeMutation.isPending || !postponedTo}
                    >
                      Перенести
                    </button>
                    <button type="button" onClick={() => executeMutation.mutate()} disabled={executeMutation.isPending}>
                      Выполнить
                    </button>
                    <label>
                      Причина пропуска
                      <input value={skipReason} onChange={(event) => setSkipReason(event.target.value)} />
                    </label>
                    <button type="button" onClick={() => skipMutation.mutate()} disabled={skipMutation.isPending}>
                      Пропустить
                    </button>
                  </div>
                  {postponeMutation.isError ? <div className="alert error">{mutationError(postponeMutation.error)}</div> : null}
                  {executeMutation.isError ? <div className="alert error">{mutationError(executeMutation.error)}</div> : null}
                  {skipMutation.isError ? <div className="alert error">{mutationError(skipMutation.error)}</div> : null}
                </div>
              ) : (
                <div className="page-state">
                  {occurrence.projected ? "Плановое выполнение доступно только для просмотра." : "Для этого выполнения нет действий."}
                </div>
              )}
            </section>
          ) : null}
        </div>
      </div>
    </section>
  );
}
