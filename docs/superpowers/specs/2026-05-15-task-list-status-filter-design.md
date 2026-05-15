# Task List Lifecycle Status Filter Design

## Summary
This spec defines the residual public API gap for filtering task lists by task lifecycle `status`.

The current implementation supports occurrence-level date projection and `occurrence_status` filtering, but it does not yet apply a lifecycle status query filter to `GET /api/v1/tasks`. The API should support both concepts because they answer different questions:
- `status` filters the task lifecycle node, such as `draft`, `pending_acceptance`, `ongoing`, `completed`, or `cancelled`.
- `occurrence_status` filters concrete occurrence rows or projected planned occurrences, such as `planned`, `postponed`, `executed`, `skipped`, `superseded`, or `cancelled`.

## Problem
The assignment-level task list contract includes filtering by task status. Without this filter, clients cannot ask for only active operational tasks, only pending delegated tasks, or only completed/cancelled tasks without fetching a broader result set and filtering client-side.

This is especially visible after the occurrence projection work: date-filtered responses can now represent occurrence state correctly, but the task lifecycle remains unfiltered unless callers use one of the existing coarse scopes.

## Public Contract
Endpoint:
- `GET /api/v1/tasks`

New query parameter:
- `status`

Allowed values:
- `draft`
- `pending_acceptance`
- `ongoing`
- `completed`
- `cancelled`

Semantics:
- `status` filters by `tasks.status`.
- The filter applies after visibility rules and before response serialization.
- The filter must work with no date range.
- The filter must work with `from` / `to` date ranges.
- The filter must compose with `scope`.
- The filter must compose with `occurrence_status` for date-filtered recurring-task responses.
- Unknown status values should return `400 Bad Request`, not silently produce an empty list or leak enum exceptions.

## Expected Behavior
When a user requests `GET /api/v1/tasks?status=ongoing`:
- only visible tasks with `tasks.status = ongoing` are returned.
- `draft`, `pending_acceptance`, `completed`, and `cancelled` tasks are excluded.

When a user requests `GET /api/v1/tasks?status=pending_acceptance&scope=delegated_to_me`:
- only visible pending delegated tasks assigned to that user are returned.

When a user requests `GET /api/v1/tasks?from=2026-05-15&to=2026-05-17&status=ongoing&occurrence_status=planned`:
- the response includes only projected or persisted planned occurrences for tasks whose lifecycle status is `ongoing`.
- planned occurrences for `draft`, `pending_acceptance`, `completed`, or `cancelled` tasks are excluded.

## Non-Goals
- Do not replace existing `scope` semantics.
- Do not rename `occurrence_status`.
- Do not infer lifecycle status from occurrence status.
- Do not expose final/deactivated tasks that are hidden by current visibility rules.
- Do not add multi-status filtering in this iteration.

## Implementation Notes
- Add a controller-level filter near `apply_scope`.
- Validate `params[:status]` against `Task.statuses.keys`.
- Return the same bad-request response shape used by invalid date filters.
- Keep filtering in ActiveRecord before loading tasks for serialization/projection.
- Add request specs for plain task lists and at least one date-filtered projected occurrence case.

## Acceptance Criteria
- `GET /api/v1/tasks?status=ongoing` returns only visible ongoing tasks.
- `GET /api/v1/tasks?status=pending_acceptance&scope=delegated_to_me` returns only delegated pending tasks visible to the caller.
- `GET /api/v1/tasks?from=...&to=...&status=ongoing&occurrence_status=planned` excludes matching occurrences from non-ongoing tasks.
- `GET /api/v1/tasks?status=invalid` returns `400 Bad Request` with a clear error message.
- Full request spec suite passes.
