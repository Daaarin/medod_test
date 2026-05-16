import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useState } from "react";
import { useLocation, useNavigate, useParams } from "react-router-dom";

function readError(error) {
  if (error?.messages?.length) {
    return error.messages.join(", ");
  }

  if (typeof error?.message === "string" && error.message.trim()) {
    return error.message;
  }

  return "Unable to load task";
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
  return tag?.attributes?.name || tag?.name || "Untitled tag";
}

function tagDescription(tag) {
  return tag?.attributes?.description || tag?.description || "";
}

function taskTags(attributes) {
  return Array.isArray(attributes?.tags) ? attributes.tags : [];
}

export function TaskDetail({ api }) {
  const { taskId } = useParams();
  const location = useLocation();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
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
  const occurrence = attributes.occurrence || location.state?.occurrence || null;
  const attachedTags = taskTags(attributes);
  const attachedTagIds = new Set(attachedTags.map((tag) => tagId(tag)));
  const availableTags = (tagsQuery.data?.data || []).filter((tag) => !attachedTagIds.has(tagId(tag)));

  useEffect(() => {
    if (task?.attributes) {
      setEditValues(emptyEditState(attributes));
      setPostponedTo(toDateTimeInput(occurrence?.scheduled_at || occurrence?.occurs_at || ""));
      setSkipReason("");
    }
  }, [attributes, occurrence, task]);

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
        completion_date: editValues.completion_date || undefined,
      }),
    onSuccess: async () => {
      setFeedback("Task saved.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const acceptMutation = useMutation({
    mutationFn: () => api.acceptTask(taskId),
    onSuccess: async () => {
      setFeedback("Task accepted.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const declineMutation = useMutation({
    mutationFn: () => api.declineTask(taskId),
    onSuccess: async () => {
      setFeedback("Task declined.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const deactivateMutation = useMutation({
    mutationFn: () => api.deactivateTask(taskId),
    onSuccess: async () => {
      setFeedback("Task deactivated.");
      await invalidateTaskData();
      navigate("/tasks", { replace: true });
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const postponeMutation = useMutation({
    mutationFn: () => api.postponeOccurrence(occurrence.id, localDateTimeToIso(postponedTo)),
    onSuccess: async () => {
      setFeedback("Occurrence postponed.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const executeMutation = useMutation({
    mutationFn: () => api.executeOccurrence(occurrence.id),
    onSuccess: async () => {
      setFeedback("Occurrence executed.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const skipMutation = useMutation({
    mutationFn: () => api.skipOccurrence(occurrence.id, skipReason || undefined),
    onSuccess: async () => {
      setFeedback("Occurrence skipped.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const attachMutation = useMutation({
    mutationFn: () => api.attachTag(taskId, selectedTagId),
    onSuccess: async () => {
      setFeedback("Tag attached.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const detachMutation = useMutation({
    mutationFn: (tagIdentifier) => api.detachTag(taskId, tagIdentifier),
    onSuccess: async () => {
      setFeedback("Tag detached.");
      await invalidateTaskData();
    },
    onError: (error) => {
      setFeedback(mutationError(error));
    },
  });

  const canShowOccurrenceActions = Boolean(occurrence?.id) && !occurrence?.projected;

  const summaryItems = useMemo(
    () => [
      ["Status", attributes.status],
      ["Kind", attributes.task_kind],
      ["Creator", attributes.creator_id],
      ["Responsible", attributes.responsible_id],
      ["Delegated", attributes.delegated_user_id],
      ["Completion date", attributes.completion_date],
      ["First run", attributes.first_run_at],
      ["Next run", attributes.next_run_at],
      ["Accepted at", attributes.accepted_at],
      ["Cancelled at", attributes.cancelled_at],
      ["End reason", attributes.end_reason],
      ["Cancellation reason", attributes.cancellation_reason],
    ],
    [attributes],
  );

  if (taskQuery.isPending) {
    return <div className="page-state">Loading task...</div>;
  }

  if (taskQuery.isError) {
    return <div className="alert error">{readError(taskQuery.error)}</div>;
  }

  return (
    <section className="stack">
      <header className="page-header">
        <p className="eyebrow">Task</p>
        <h2>{attributes.name || "Untitled task"}</h2>
        <p>{attributes.description || "No description"}</p>
      </header>

      {feedback ? <div className="alert">{feedback}</div> : null}

      <div className="panel">
        <h3>Edit</h3>
        <form
          className="stack"
          onSubmit={(event) => {
            event.preventDefault();
            updateMutation.mutate();
          }}
        >
          <div className="form-grid">
            <label>
              Name
              <input
                value={editValues.name}
                onChange={(event) => setEditValues((current) => ({ ...current, name: event.target.value }))}
              />
            </label>
            <label>
              Completion date
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
            Description
            <textarea
              value={editValues.description}
              onChange={(event) => setEditValues((current) => ({ ...current, description: event.target.value }))}
            />
          </label>
          {updateMutation.isError ? <div className="alert error">{mutationError(updateMutation.error)}</div> : null}
          <button type="submit" disabled={updateMutation.isPending}>
            Save changes
          </button>
        </form>
      </div>

      <div className="panel">
        <h3>Actions</h3>
        <div className="toolbar">
          <button
            type="button"
            onClick={() => acceptMutation.mutate()}
            disabled={attributes.status !== "pending_acceptance" || acceptMutation.isPending}
          >
            Accept
          </button>
          <button
            type="button"
            onClick={() => declineMutation.mutate()}
            disabled={attributes.status !== "pending_acceptance" || declineMutation.isPending}
          >
            Decline
          </button>
          <button
            type="button"
            onClick={() => deactivateMutation.mutate()}
            disabled={["completed", "cancelled"].includes(attributes.status) || deactivateMutation.isPending}
          >
            Deactivate
          </button>
        </div>
        {acceptMutation.isError ? <div className="alert error">{mutationError(acceptMutation.error)}</div> : null}
        {declineMutation.isError ? <div className="alert error">{mutationError(declineMutation.error)}</div> : null}
        {deactivateMutation.isError ? <div className="alert error">{mutationError(deactivateMutation.error)}</div> : null}
      </div>

      <div className="panel">
        <h3>Task details</h3>
        <dl className="meta-grid">
          {summaryItems.map(([label, value]) => (
            <div key={label}>
              <dt>{label}</dt>
              <dd>{displayValue(value)}</dd>
            </div>
          ))}
        </dl>
      </div>

      <div className="panel stack">
        <h3>Tags</h3>
        {tagsQuery.isPending ? <div className="page-state">Loading tags...</div> : null}
        {tagsQuery.isError ? <div className="alert error">{readError(tagsQuery.error)}</div> : null}
        {attachedTags.length ? (
          <div className="stack">
            {attachedTags.map((tag) => (
              <div className="row-between" key={tagId(tag)}>
                <div>
                  <strong>{tagName(tag)}</strong>
                  {tagDescription(tag) ? <p>{tagDescription(tag)}</p> : null}
                </div>
                <button
                  type="button"
                  onClick={() => detachMutation.mutate(tagId(tag))}
                  disabled={detachMutation.isPending}
                >
                  Detach
                </button>
              </div>
            ))}
          </div>
        ) : (
          <div className="page-state">This response does not include attached tags yet.</div>
        )}
        {!tagsQuery.isPending && availableTags.length ? (
          <div className="toolbar">
            <label>
              Attach tag
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
              Attach
            </button>
          </div>
        ) : null}
        {attachMutation.isError ? <div className="alert error">{mutationError(attachMutation.error)}</div> : null}
        {detachMutation.isError ? <div className="alert error">{mutationError(detachMutation.error)}</div> : null}
      </div>

      {occurrence ? (
        <div className="panel">
          <h3>Occurrence</h3>
          <dl className="meta-grid">
            <div>
              <dt>Status</dt>
              <dd>{displayValue(occurrence.status)}</dd>
            </div>
            <div>
              <dt>Scheduled at</dt>
              <dd>{displayValue(occurrence.scheduled_at)}</dd>
            </div>
            <div>
              <dt>Actual at</dt>
              <dd>{displayValue(occurrence.actual_at)}</dd>
            </div>
            <div>
              <dt>Postponed to</dt>
              <dd>{displayValue(occurrence.postponed_to)}</dd>
            </div>
            <div>
              <dt>Skip reason</dt>
              <dd>{displayValue(occurrence.skip_reason)}</dd>
            </div>
            <div>
              <dt>Generated at</dt>
              <dd>{displayValue(occurrence.generated_at)}</dd>
            </div>
          </dl>

          {canShowOccurrenceActions ? (
            <div className="stack">
              <label>
                Postpone to
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
                  Postpone
                </button>
                <button type="button" onClick={() => executeMutation.mutate()} disabled={executeMutation.isPending}>
                  Execute
                </button>
                <label>
                  Skip reason
                  <input value={skipReason} onChange={(event) => setSkipReason(event.target.value)} />
                </label>
                <button type="button" onClick={() => skipMutation.mutate()} disabled={skipMutation.isPending}>
                  Skip
                </button>
              </div>
              {postponeMutation.isError ? <div className="alert error">{mutationError(postponeMutation.error)}</div> : null}
              {executeMutation.isError ? <div className="alert error">{mutationError(executeMutation.error)}</div> : null}
              {skipMutation.isError ? <div className="alert error">{mutationError(skipMutation.error)}</div> : null}
            </div>
          ) : (
            <div className="page-state">
              {occurrence.projected ? "Projected occurrences are read-only until persisted." : "This occurrence is not actionable."}
            </div>
          )}
        </div>
      ) : null}
    </section>
  );
}
