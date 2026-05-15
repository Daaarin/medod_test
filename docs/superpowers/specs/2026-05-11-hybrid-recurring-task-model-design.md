# Hybrid Recurring Task Model Design

## Summary
This design defines a hybrid model for periodic tasks in the Rails app.

The model combines:
- a long-lived `Task` lineage node
- a `RecurrenceRule` that defines future behavior
- a single persisted future `TaskOccurrence` per active recurring task, plus historical occurrences
- an immutable `TaskEvent` audit trail

The goal is to support one-time tasks, recurring tasks, postponements, structural replacements, and full history without materializing the full future or mutating history in place.

## Goals
- Support one-time tasks and recurring tasks in the same business domain.
- Keep the history immutable and auditable.
- Support postponement of one occurrence without changing future recurrence.
- Support responsible changes and schedule changes by creating a new child task node.
- Preserve a single-parent lineage for audit and navigation.
- Avoid precreating more than one future scheduled occurrence per active recurring task.
- Keep calendar queries usable through `next_run_at` and rule-based projections.

## Non-Goals
- Multi-parent lineage.
- Reopening or resuming a final task node.
- Encoding every scheduler state as a task status.
- Supporting multiple executions per day in the first iteration.
- Precomputing the entire future lifetime of a recurring task.
- Using PaperTrail as the canonical history system.

## Core Concepts

### Task
`Task` is the long-lived operational node.

It stores the current visible state of the business object:
- title
- description
- responsible
- lifecycle status
- end_reason
- lineage pointers
- cached scheduling fields such as `next_run_at`

`Task` is not the execution history itself.

### RecurrenceRule
`RecurrenceRule` defines how future executions should be generated.

It belongs to the currently active task node. A one-time task does not have a recurrence rule.

The current scope includes:
- one-time execution at a chosen date/time
- every N days
- every N months at a chosen day of month
- every N years at a chosen day and month
- weekday-pattern schedules such as even or odd weekdays
- even or odd days of month

Parity-based weekday patterns are interpreted against the weekday ordinal, not the number of days since creation.

The design leaves room for future support of multiple runs per day, but that is not part of this version.

### TaskOccurrence
`TaskOccurrence` is a concrete planned run for a specific date/time.

Occurrences are generated only for the next scheduled occurrence plus historical records, not for the full future.

They are used for:
- calendar display
- “what is due next?” queries
- postponement of a single run
- auditability of executed, skipped, or superseded runs

### TaskEvent
`TaskEvent` is the append-only history log.

This project intentionally uses its own history model rather than PaperTrail so that domain events remain explicit.

It records every important event:
- creation
- acceptance
- title/description change
- execution
- skip
- postponement
- completion
- cancellation
- clone/split caused by responsible change or schedule change

This is the source of truth for what happened over time.

## Status Model

### Task statuses
The task lifecycle uses the following statuses:
- `draft`
- `pending_acceptance`
- `ongoing`
- `completed`
- `cancelled`

Meaning:
- `draft` means created but not fully filled in.
- `pending_acceptance` means created by someone other than the responsible person and waiting for confirmation.
- `ongoing` means accepted and currently active.
- `completed` means the task lineage is finished permanently.
- `cancelled` means the task lineage is revoked and cannot continue.

`completed` can be set either:
- automatically, when the task series naturally reaches its end and no further runs are expected
- manually, when a person explicitly decides the lineage should stop

`end_reason` explains why a final node ended, especially for retired nodes created by structural replacement.
Recommended values include:
- `series_completed`
- `manual_cancelled`
- `responsible_changed`
- `schedule_changed`

Final task nodes are view-only:
- no update
- no delete
- no reschedule

### Occurrence statuses
Occurrences use a separate lifecycle:
- `planned`
- `postponed`
- `executed`
- `skipped`
- `superseded`
- `cancelled`

Meaning:
- `planned` means scheduled but not yet handled.
- `postponed` means this specific occurrence moved to a new date/time.
- `executed` means the run happened.
- `skipped` means the run did not happen and was intentionally skipped.
- `superseded` means the occurrence became invalid because its parent task was structurally replaced.
- `cancelled` means the occurrence was voided because the task lineage ended.

## Lineage Rules

### Single parent chain
Each task can have at most one parent task.

This creates a strict lineage chain:
- child task points to parent task
- root task can be cached via `root_task_id`
- ancestors are readable for audit, but only one active node exists per lineage branch

### Structural replacement
If responsible changes or recurrence changes:
- the old task becomes immutable immediately
- the old task becomes final with `status = cancelled` and an appropriate `end_reason`
- a new child task is created
- the child inherits a snapshot of the parent’s current fields at split time
- the child becomes the new active operational node

This is the canonical way to preserve history without mutating old business meaning.

### Metadata edits
Title and description changes do not create a new task.

Instead:
- the same task node is updated in place
- a `TaskEvent` is appended with old and new values
- the task remains the same lineage node

This applies only to metadata edits. It does not apply to responsible changes or schedule changes.

## Scheduling Rules

### One-time tasks
One-time tasks have a single planned execution and no recurrence rule.

They still use:
- `next_run_at`
- occurrence rows
- event history

But they do not support per-task next-occurrence overrides.

### Recurring tasks
Recurring tasks own a recurrence rule and maintain exactly one future scheduled occurrence at a time.

The system uses:
- a global default next-occurrence policy
- an optional per-task override

The per-task override is allowed only for recurring tasks.

### Next occurrence policy
The system persists only the next actionable scheduled occurrence for each active recurring task.

Already executed, skipped, postponed, or superseded occurrences remain persisted as history.

Future calendar entries beyond the next persisted occurrence are computed from the recurrence rule on demand.

### `next_run_at`
`next_run_at` is a cached operational field.

It is updated after:
- execution
- postponement
- next occurrence generation
- structural replacement

It is not the source of truth for recurrence. The recurrence rule is.

## Data Model

### `tasks`
Current operational node and lineage anchor.

Recommended fields:
- `id`
- `parent_task_id`
- `root_task_id`
- `task_kind` (`one_time`, `recurring`)
- `status`
- `end_reason`
- `title`
- `description`
- `responsible_id`
- `first_run_at`
- `next_run_at`
- `completed_at`
- `cancelled_at`
- `created_at`
- `updated_at`

Notes:
- `parent_task_id` is a self-reference.
- `root_task_id` is a lineage cache for easier queries.
- `task_kind` is used to distinguish one-time from recurring tasks.
- `end_reason` is nullable until a final state is reached.

### `recurrence_rules`
Schedule definition for recurring tasks.

Recommended fields:
- `id`
- `task_id` unique
- `rule_type`
- `interval_value`
- `day_of_month`
- `day_of_month_parity`
- `month_of_year`
- `weekday`
- `weekday_parity`
- `execution_time`
- `timezone`
- `date_start`
- `date_end`
- `created_at`
- `updated_at`

Notes:
- The design does not rely on a single overloaded `unit` field for all schedule shapes.
- The rule stores whichever selectors are relevant for the chosen recurrence pattern.
- `day_of_month_parity` supports even/odd day-of-month schedules.
- `weekday_parity` supports even/odd weekday schedules.
- One-time tasks do not have a row here.

### `task_occurrences`
Concrete scheduled runs for the current next action and historical run records.

Recommended fields:
- `id`
- `task_id`
- `scheduled_at`
- `status`
- `actual_at`
- `postponed_to`
- `skip_reason`
- `generated_at`
- `created_at`
- `updated_at`

Notes:
- The system keeps at most one future scheduled occurrence per active recurring task.
- Historical occurrences remain persisted after execution, skip, postponement, or cancellation.
- Executed, skipped, postponed, or superseded occurrences remain as historical facts.
- When a task is structurally replaced, any future occurrence already generated for the retired node becomes `superseded` or `cancelled` depending on the reason.

### `task_events`
Append-only audit trail.

Recommended fields:
- `id`
- `task_id`
- `occurrence_id` nullable
- `event_type`
- `actor_id`
- `occurred_at`
- `payload_json`
- `created_at`

Notes:
- `payload_json` stores old/new values, reasons, and other context.
- Event rows are never updated in place for business changes.

## Key Flows

### 1. Create a one-time task
1. Create a `tasks` row with `task_kind = one_time`.
2. Create one planned occurrence for the selected date/time.
3. Append a `task_created` event.
4. Update `next_run_at` to the one planned occurrence time.

### 2. Create a recurring task
1. Create a `tasks` row with `task_kind = recurring`.
2. Create the `recurrence_rules` row.
3. Generate only the next scheduled occurrence.
4. Append a `task_created` event.
5. Set `next_run_at` to the earliest planned occurrence.

### 3. Postpone one occurrence
1. Locate the current planned occurrence.
2. Mark that occurrence as `postponed`.
3. Store the new postponed time on that occurrence.
4. Append a `task_postponed` event.
5. Recompute `next_run_at`.

This changes only one occurrence, not the recurrence rule and not the future cadence.

### 4. Execute an occurrence
1. Append an execution event.
2. Mark the occurrence as `executed`.
3. Recompute `next_run_at`.
4. If the task is one-time, the task may transition to `completed`.
5. If the task is recurring and still active, generate the next scheduled occurrence from the recurrence rule.

### 5. Change title or description
1. Update the fields on the same active task node.
2. Append a metadata-change event with old and new values.
3. Keep the same lineage node.

### 6. Change responsible
1. Freeze the current task node.
2. Mark it `cancelled` with `end_reason = responsible_changed`.
3. Append an event explaining the change.
4. Create a child task node with the new responsible person and a snapshot of the parent’s current state.
5. Generate future occurrences for the child task only.

### 7. Change schedule
1. Freeze the current task node.
2. Mark it `cancelled` with `end_reason = schedule_changed`.
3. Append an event explaining the schedule edit.
4. Create a child task node with the new recurrence rule and a snapshot of the parent’s current state.
5. Generate future occurrences for the child task only.

### 8. Complete or cancel a task lineage
1. Append a terminal event.
2. Mark the lineage node as `completed` or `cancelled`.
3. Mark remaining unexecuted future occurrences as `cancelled`.
4. Keep the node viewable but immutable.

For recurring tasks, completion may happen:
- automatically after the last intended occurrence is finished
- manually before the series ends if the business wants to stop it early

## Invariants
- A task has at most one parent.
- A task is either active or final; final nodes are immutable.
- Title and description edits stay on the same node.
- Responsible changes create a new child task.
- Schedule changes create a new child task.
- A child task inherits a snapshot of the parent at split time.
- A recurring task must always have exactly one active recurrence rule.
- One-time tasks must not accept per-task next-occurrence overrides.
- `TaskEvent` rows are append-only.
- History must remain readable even if current task fields change later.

## Risks and Tradeoffs

### Storage growth
`TaskOccurrence` rows can grow over time because executed and skipped occurrences are retained.

Mitigation:
- only generate one future occurrence per active recurring task
- retain only actual historical occurrences, not the entire future

### Rule complexity
A single overloaded schedule enum would not handle all supported patterns cleanly.

Mitigation:
- use a rule record with pattern-specific nullable selectors
- keep unsupported future patterns out of the first version

### Lineage complexity
Deep chains can become difficult to inspect if every edit creates a new node.

Mitigation:
- only structural edits create new nodes
- metadata edits stay on the same node
- show a condensed parent summary by default in the UI

### Scheduler consistency
If execution updates fail halfway through, `next_run_at` and occurrence status can diverge.

Mitigation:
- update the occurrence/event row and cached task fields atomically
- derive `next_run_at` from the rule and current occurrence state after each mutation

## Testing Strategy
- Verify one-time task execution produces a single occurrence and a final state.
- Verify recurring tasks keep only one future scheduled occurrence at a time.
- Verify postponement changes one occurrence only.
- Verify responsible change creates a child task and freezes the parent.
- Verify schedule change creates a child task and freezes the parent.
- Verify title/description edits stay on the same task node.
- Verify final tasks are immutable.
- Verify event rows are append-only.
- Verify per-task next-occurrence overrides are rejected for one-time tasks.
- Verify `next_run_at` is recomputed correctly after execution, postponement, and replacement.

## Acceptance Criteria
- The system can represent one-time and recurring tasks without ambiguous status semantics.
- The system can archive old tasks with `end_reason = responsible_changed` or `end_reason = schedule_changed` and keep them viewable but immutable.
- The system can postpone one occurrence without changing future recurrence.
- The system can reconstruct the task story from `task_events`.
- The system can show upcoming work without precreating the full future.
- The system can support lineage queries using a single-parent chain.

## Decision Summary
The final design is:
- `Task` as the long-lived operational node
- `RecurrenceRule` as the schedule source of truth
- `TaskOccurrence` as the concrete planning layer
- `TaskEvent` as the immutable audit trail
- single-parent lineage for structural changes
- in-place metadata edits for title and description
- child-node creation for responsible changes and schedule changes
- only one persisted next occurrence per active recurring task
