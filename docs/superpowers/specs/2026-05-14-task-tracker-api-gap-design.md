# Task Tracker API Gap Design

## Summary
This design defines the missing public API and supporting data model needed to satisfy `tmp/task.md` on top of the current Rails branch.

The assignment is simpler than the current `hybrid-recurring-task-model` branch. The public contract should therefore expose a clean task tracker API with:
- authenticated staff users
- CRUD for tasks
- task list filtering by date and status
- delegated task acceptance and decline
- task-tag attachment and detachment
- immutable mandatory system tags
- recurrence support for the four required schedule types plus documented extensions
- occurrence-level state so repeated tasks do not share one status
- bounded calendar projection so the system does not precreate infinite future rows

## Hard Decisions
- Authentication is in scope because the domain is staff task assignment. Prefer Devise if it stays clean in Rails API mode; otherwise use a small first-party bearer-token flow instead of forcing session-oriented behavior.
- `Task#name` is the canonical field. Rename the current `title` column and update specs, services, event payloads, and Swagger instead of maintaining a public `name` / internal `title` split.
- Database deletion is prohibited for business records. Use `deactivated_at` for task and association removal behavior; do not use deactivation as a lifecycle status.
- Keep the current task lifecycle statuses unless implementation evidence proves they are wrong: `draft`, `pending_acceptance`, `ongoing`, `completed`, `cancelled`.
- Decline is not a lifecycle status. A declined task is `status = cancelled`, `end_reason = declined`, and `cancellation_reason = "was declined"` in this iteration.
- The public API should not expose internal scheduling internals such as lineage or audit-event plumbing unless needed for a specific workflow.
- The recurrence implementation must support read-time projection; it must not materialize the full future.
- The public recurrence contract must support at least the modes in the assignment:
  - every N days
  - monthly on a fixed day of month
  - specific dates
  - even or odd days of month
- Extra recurrence modes already present in the branch, such as weekday parity or yearly schedules, may remain if they are documented, tested, and do not obscure the assignment-required behavior.

## Auth And Users

Public user fields:
- `id`
- `email`
- `role`
- `name`
- `last_name`

Role values:
- `administrator`
- `doctor`
- `nurse`

Semantics:
- every API request that mutates task data must be authenticated.
- administrators can view every task.
- doctors and nurses can view only tasks connected to them by `creator_id`, `responsible_id`, or `delegated_user_id`.
- `creator_id` stores the user who created a task.
- `responsible_id` stores the user who owns accepted/self-created work.
- `delegated_user_id` stores the user who must accept or decline a pending delegated task.
- `responsible_id` may be null only when the task still has a meaningful owner context through `creator_id` or `delegated_user_id`.
- a task is invalid if `creator_id`, `responsible_id`, and `delegated_user_id` are all null.

## Public API Contract

### Task
Public task fields:
- `id`
- `name`
- `description`
- `completion_date`
- `status`
- `creator_id`
- `responsible_id`
- `delegated_user_id`
- `end_reason`
- `cancellation_reason`
- `accepted_at`
- `cancelled_at`
- `deactivated_at`
- `tags`
- `recurrence_rule` when the task is periodic

Semantics:
- `completion_date` is the user-facing due date / scheduled date.
- `status` applies to the task instance returned by the API, not to all future repeats.
- For recurring tasks, list responses should return the visible occurrences within the requested window.
- self-created tasks have `responsible_id = current_user.id`, `delegated_user_id = null`, and can move to `ongoing`.
- delegated tasks start as `pending_acceptance`, have `delegated_user_id = assigned_user.id`, and do not require `responsible_id` until acceptance.
- accepting a task sets `responsible_id = current_user.id`, clears `delegated_user_id`, sets `status = ongoing`, sets `accepted_at`, and appends an audit event.
- declining a task sets `status = cancelled`, `end_reason = declined`, `cancellation_reason = "was declined"`, sets `cancelled_at`, and appends an audit event.
- deactivation hides a task from default list results but does not erase it from the database.

### Tag
Public tag fields:
- `id`
- `name`
- `description`
- `is_system_tag`
- `deactivated_at`

Semantics:
- system tags are seeded and immutable.
- `is_system_tag = true` means the record cannot be renamed, deleted, or deactivated.
- system tags required by the assignment:
  - `Отчётность`
  - `Операции`
  - `Звонок`

### RecurrenceRule
Public recurrence fields:
- `rule_type`
- `interval_value`
- `day_of_month`
- `day_of_month_parity`
- `month_of_year`
- `weekday`
- `weekday_parity`
- `date_start`
- `date_end`
- `timezone`
- `execution_time`
- `specific_dates`

Semantics:
- `specific_dates` is an explicit list of dates for the "specific dates" recurrence type.
- recurrence rules belong to one task.
- the rule is the source of truth; projected occurrences are derived from it.
- the assignment-required modes must be first-class in validation and Swagger.
- additional recurrence modes are extensions and must be clearly documented as extensions.

### TaskOccurrence
Public occurrence fields:
- `id`
- `task_id`
- `scheduled_at`
- `status`
- `actual_at`
- `postponed_to`
- `skip_reason`

Semantics:
- each occurrence has independent status.
- changing one occurrence must not mutate yesterday’s or tomorrow’s occurrence.
- occurrence-level postpone / cancel / execute actions are allowed to create exceptions.

## Data Model

### `tasks`
Store the task entity itself.

Recommended columns:
- `name`
- `description`
- `completion_date`
- `status`
- `creator_id`
- `responsible_id`
- `delegated_user_id`
- `end_reason`
- `cancellation_reason`
- `accepted_at`
- `cancelled_at`
- `deactivated_at`
- timestamps

Keep the current branch’s internal scheduling columns only if they are still needed by the recurrence engine. Do not expose them as the public contract.

Recommended constraints:
- foreign keys from `creator_id`, `responsible_id`, and `delegated_user_id` to `users.id`
- `responsible_id` nullable
- database check constraint requiring at least one of `creator_id`, `responsible_id`, or `delegated_user_id`
- default query scope behavior should exclude `deactivated_at IS NOT NULL`, but avoid Rails `default_scope`; use explicit query methods.

### `tags`
Store reusable tags.

Recommended columns:
- `name`
- `description`
- `is_system_tag` boolean default `false` not null
- `deactivated_at`
- timestamps

### `task_tags`
Join table for many-to-many task/tag relationships.

Recommended columns:
- `task_id`
- `tag_id`
- `deactivated_at`
- timestamps

Recommended constraints:
- unique index on `[task_id, tag_id]`

### `recurrence_rules`
One schedule per recurring task.

Recommended columns:
- `task_id`
- `rule_type`
- `interval_value`
- `day_of_month`
- `day_of_month_parity`
- `month_of_year`
- `weekday`
- `weekday_parity`
- `date_start`
- `date_end`
- `timezone`
- `execution_time`
- timestamps

### `recurrence_rule_dates`
Normalized list of explicit dates for the "specific dates" recurrence mode.

Recommended columns:
- `recurrence_rule_id`
- `run_date`
- timestamps

### `task_occurrences`
Persist the current occurrence state and historical occurrence rows.

Recommended columns:
- `task_id`
- `scheduled_at`
- `status`
- `actual_at`
- `postponed_to`
- `skip_reason`
- `generated_at`
- timestamps

Recommended constraint:
- one current occurrence per task at a time

## Behavioral Rules

### List endpoint
The list endpoint should accept a time window and status filters.

Behavior:
- if a task is recurring, return only the occurrences that fall inside the requested window
- if a task is one-time, return the single task occurrence if it is inside the window
- filter by occurrence status, not by series status alone
- default task lists exclude deactivated rows
- administrators can list and inspect every non-deactivated task by default
- doctors and nurses can list and inspect only tasks where they are the creator, responsible user, or delegated user
- authenticated users can request task scopes such as assigned to me, delegated to me, or created by me inside their authorization boundary

### Acceptance flow
Delegated tasks use `pending_acceptance`.

Behavior:
- only `delegated_user_id` can accept a delegated task.
- accept sets `responsible_id` to the accepting user and clears `delegated_user_id`.
- only `delegated_user_id` can decline a delegated task.
- decline cancels the task with `end_reason = declined` and `cancellation_reason = "was declined"`.
- future custom cancellation reasons should fit the same `cancellation_reason` field without changing the status model.

### Deactivation
Business records are not deleted from the database.

Behavior:
- task removal sets `deactivated_at`.
- task/tag detachment sets `task_tags.deactivated_at`.
- system tags cannot be deactivated.
- deactivated records remain available to administrative or audit queries.

### Infinite recurrence
Do not precreate a lifetime of future rows.

Behavior:
- persist the current actionable occurrence
- compute future occurrences only for the requested window
- stop projection at `date_end` if present

### Single-occurrence state
State changes must apply to one occurrence only.

Behavior:
- mark an occurrence executed without mutating other occurrences
- postpone one occurrence without rewriting the recurrence rule
- skip one occurrence without changing future dates

### Immutable system tags
System tags are write-protected.

Behavior:
- Rails validation blocks rename/delete/deactivation
- PostgreSQL trigger blocks direct SQL updates/deletes/deactivation
- seed data creates the required tags on initial setup

## Out of Scope
- multi-parent lineage
- exposing internal event stream in the public API
- precomputing every future occurrence

## Acceptance Criteria
- Users can authenticate and task mutations require an authenticated user.
- Users have roles and names suitable for medical staff task assignment.
- Administrators can view every task.
- Doctors and nurses can view only tasks connected to them by `creator_id`, `responsible_id`, or `delegated_user_id`.
- The API can create, read, update, and request removal of tasks via non-destructive deactivation.
- Removal behavior deactivates records and does not remove database rows.
- A delegated user can see tasks pending their acceptance.
- A delegated user can accept a task and become responsible for it.
- A delegated user can decline a task, which cancels it with reason `"was declined"`.
- The task list can filter by date window and status.
- Tags can be attached and detached from tasks.
- The required three tags exist after setup and cannot be renamed or deleted.
- Recurring tasks are shown by window, not by infinite precreation.
- The four assignment-required recurrence modes are supported and tested.
- Extra recurrence modes are documented as extensions when exposed.
- One occurrence can be changed without changing the other occurrences in the same series.
