# Hybrid Recurring Task Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the recurring-task domain model with lineage, immutable history, recurrence rules, and one persisted future occurrence per active recurring task.

**Architecture:** Keep `Task` as the long-lived operational node, `RecurrenceRule` as the schedule source of truth, `TaskOccurrence` as the persisted current/final scheduled run, and `TaskEvent` as the immutable audit log. Put recurrence math in small service objects under `app/services/task_scheduling`, and put lifecycle mutations in small task services under `app/services/tasks` so structural replacement, postponement, and next-occurrence generation stay transactional and testable.

**Tech Stack:** Rails 8, PostgreSQL, RSpec, ActiveRecord, Solid Queue already present but not required for this slice.

---

## File Structure

- `db/migrate/20260512000001_create_tasks.rb` - task lineage, status, and end-reason columns.
- `db/migrate/20260512000002_create_recurrence_rules.rb` - recurrence rule schema and parity selectors.
- `db/migrate/20260512000003_create_task_occurrences.rb` - one current future occurrence plus historical occurrence rows.
- `db/migrate/20260512000004_create_task_events.rb` - immutable task history.
- `app/models/task.rb` - task lifecycle, lineage, associations, and immutability helpers.
- `app/models/recurrence_rule.rb` - recurrence rule validations and pattern-specific selectors.
- `app/models/task_occurrence.rb` - occurrence lifecycle and constraint that only one planned future row exists per task.
- `app/models/task_event.rb` - append-only audit record.
- `app/services/task_scheduling/next_occurrence_calculator.rb` - compute the next scheduled run from a task and recurrence rule.
- `app/services/task_scheduling/calendar_projection.rb` - compute visible schedule entries on demand for calendar views.
- `app/services/tasks/append_event.rb` - one write path for appending task events.
- `app/services/tasks/advance_occurrence.rb` - mark one occurrence executed and materialize the next one when needed.
- `app/services/tasks/postpone_occurrence.rb` - move one occurrence without changing future recurrence.
- `app/services/tasks/split_lineage.rb` - retire a task with `end_reason` and create its child task.
- `spec/models/*.rb` - model and constraint coverage.
- `spec/services/task_scheduling/*.rb` - recurrence math coverage.
- `spec/services/tasks/*.rb` - lifecycle, postponement, and lineage split coverage.
- `spec/integration/hybrid_task_flow_spec.rb` - one end-to-end flow that exercises the whole model.

## Task 1: Create the database tables and core models

**Files:**
- Create: `db/migrate/20260512000001_create_tasks.rb`
- Create: `db/migrate/20260512000002_create_recurrence_rules.rb`
- Create: `db/migrate/20260512000003_create_task_occurrences.rb`
- Create: `db/migrate/20260512000004_create_task_events.rb`
- Create: `app/models/task.rb`
- Create: `app/models/recurrence_rule.rb`
- Create: `app/models/task_occurrence.rb`
- Create: `app/models/task_event.rb`
- Create: `spec/models/task_spec.rb`
- Create: `spec/models/recurrence_rule_spec.rb`
- Create: `spec/models/task_occurrence_spec.rb`
- Create: `spec/models/task_event_spec.rb`

- [ ] **Step 1: Write the failing model specs**

```ruby
# spec/models/task_spec.rb
require "rails_helper"

RSpec.describe Task, type: :model do
  it "tracks lineage and final state" do
    task = described_class.new(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )

    expect(task).to be_valid
    expect(task.task_kind).to eq("recurring")
    expect(task.status).to eq("ongoing")
    expect(task.final?).to be(false)
  end

  it "requires end_reason for a final task" do
    task = described_class.new(
      task_kind: :recurring,
      status: :cancelled,
      title: "Check email",
      responsible_id: 42
    )

    expect(task).not_to be_valid
    expect(task.errors[:end_reason]).to include("must be present for final tasks")
  end
end
```

```ruby
# spec/models/task_occurrence_spec.rb
require "rails_helper"

RSpec.describe TaskOccurrence, type: :model do
  it "allows one planned future occurrence per task" do
    task = Task.create!(task_kind: :recurring, status: :ongoing, title: "Check email", responsible_id: 42)
    task.task_occurrences.create!(scheduled_at: Time.zone.parse("2026-05-12 10:00"), status: :planned)

    duplicate = task.task_occurrences.new(scheduled_at: Time.zone.parse("2026-05-19 10:00"), status: :planned)
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:task_id]).to include("already has a planned occurrence")
  end
end
```

```ruby
# spec/models/recurrence_rule_spec.rb
require "rails_helper"

RSpec.describe RecurrenceRule, type: :model do
  it "accepts parity-based day and weekday selectors" do
    rule = described_class.new(
      rule_type: :day_of_month_parity,
      day_of_month_parity: :even,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    expect(rule).to be_valid
  end
end
```

```ruby
# spec/models/task_event_spec.rb
require "rails_helper"

RSpec.describe TaskEvent, type: :model do
  it "persists payload data for an audit event" do
    task = Task.create!(task_kind: :one_time, status: :ongoing, title: "Check email", responsible_id: 42)
    event = described_class.create!(
      task: task,
      event_type: :created,
      actor_id: 42,
      occurred_at: Time.zone.parse("2026-05-10 09:00"),
      payload_json: { title: "Check email" }
    )

    expect(event.payload_json["title"]).to eq("Check email")
  end
end
```

- [ ] **Step 2: Run the specs and confirm they fail**

Run:

```bash
bundle exec rspec spec/models/task_spec.rb spec/models/task_occurrence_spec.rb -v
```

Expected: failures for missing models, missing methods, and missing validations.

- [ ] **Step 3: Implement the schema and model skeletons**

Create the four migrations with:
- `tasks`: `parent_task_id`, `root_task_id`, `task_kind`, `status`, `end_reason`, `title`, `description`, `responsible_id`, `first_run_at`, `next_run_at`, `completed_at`, `cancelled_at`
- `recurrence_rules`: `task_id`, `rule_type`, `interval_value`, `day_of_month`, `day_of_month_parity`, `month_of_year`, `weekday`, `weekday_parity`, `execution_time`, `timezone`, `date_start`, `date_end`
- `task_occurrences`: `task_id`, `scheduled_at`, `status`, `actual_at`, `postponed_to`, `skip_reason`, `generated_at`
- `task_events`: `task_id`, `occurrence_id`, `event_type`, `actor_id`, `occurred_at`, `payload_json`

Implement the models with:
- `Task` `belongs_to :parent_task, class_name: "Task", optional: true`
- `Task` `belongs_to :root_task, class_name: "Task", optional: true`
- `Task` `has_one :recurrence_rule, dependent: :destroy`
- `Task` `has_many :task_occurrences, dependent: :destroy`
- `Task` `has_many :task_events, dependent: :destroy`
- enums for `task_kind`, `status`, and `end_reason`
- `Task#active?`, `Task#final?`, and `Task#retire!(end_reason:)`
- `TaskOccurrence` uniqueness validation or partial unique index behavior for one planned row per task
- `TaskEvent` as a plain append-only record with no update helpers

Add a database uniqueness index that enforces a single `planned` occurrence per `task_id`.

- [ ] **Step 4: Run the specs and confirm they pass**

Run:

```bash
bundle exec rspec spec/models/task_spec.rb spec/models/task_occurrence_spec.rb spec/models/recurrence_rule_spec.rb spec/models/task_event_spec.rb -v
```

Expected: `0 failures, 0 errors`.

- [ ] **Step 5: Commit**

```bash
git add db/migrate/2026051200000*_*.rb app/models/task.rb app/models/recurrence_rule.rb app/models/task_occurrence.rb app/models/task_event.rb spec/models
git commit -m "feat: add recurring task domain tables"
```

## Task 2: Implement recurrence math and calendar projection

**Files:**
- Create: `app/services/task_scheduling/next_occurrence_calculator.rb`
- Create: `app/services/task_scheduling/calendar_projection.rb`
- Create: `spec/services/task_scheduling/next_occurrence_calculator_spec.rb`
- Create: `spec/services/task_scheduling/calendar_projection_spec.rb`

- [ ] **Step 1: Write the failing service specs**

```ruby
# spec/services/task_scheduling/next_occurrence_calculator_spec.rb
require "rails_helper"

RSpec.describe TaskScheduling::NextOccurrenceCalculator do
  it "finds the next even day of month" do
    task = Task.new(
      task_kind: :recurring,
      status: :ongoing,
      title: "Reconcile invoices",
      responsible_id: 42
    )
    task.build_recurrence_rule(
      rule_type: :day_of_month_parity,
      day_of_month_parity: :even,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    result = described_class.call(task: task, from_time: Time.zone.parse("2026-05-11 09:00"))
    expect(result).to eq(Time.zone.parse("2026-05-12 10:00"))
  end

  it "finds the next odd weekday" do
    task = Task.new(task_kind: :recurring, status: :ongoing, title: "Check email", responsible_id: 42)
    task.build_recurrence_rule(
      rule_type: :weekday_parity,
      weekday_parity: :odd,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    result = described_class.call(task: task, from_time: Time.zone.parse("2026-05-11 09:00"))
    expect(result).to be_a(Time)
  end
end
```

```ruby
# spec/services/task_scheduling/calendar_projection_spec.rb
require "rails_helper"

RSpec.describe TaskScheduling::CalendarProjection do
  it "returns projected dates from the recurrence rule" do
    task = Task.new(task_kind: :recurring, status: :ongoing, title: "Check email", responsible_id: 42)
    task.build_recurrence_rule(
      rule_type: :every_n_days,
      interval_value: 2,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    projected = described_class.call(
      task: task,
      range_start: Time.zone.parse("2026-05-01 00:00"),
      range_end: Time.zone.parse("2026-05-10 23:59")
    )

    expect(projected.map { |t| t.to_date }).to eq([Date.new(2026, 5, 1), Date.new(2026, 5, 3), Date.new(2026, 5, 5), Date.new(2026, 5, 7), Date.new(2026, 5, 9)])
  end
end
```

- [ ] **Step 2: Run the specs and confirm they fail**

Run:

```bash
bundle exec rspec spec/services/task_scheduling/next_occurrence_calculator_spec.rb spec/services/task_scheduling/calendar_projection_spec.rb -v
```

Expected: failures for missing service objects and missing recurrence logic.

- [ ] **Step 3: Implement the recurrence services**

Implement `TaskScheduling::NextOccurrenceCalculator.call(task:, from_time:)` so it:
- returns the next valid occurrence for one-time tasks and recurring tasks
- respects `date_start`, `date_end`, `execution_time`, and `timezone`
- supports `every_n_days`, `every_n_months`, `every_n_years`, `day_of_month_parity`, and `weekday_parity`
- skips past occurrences and returns `nil` when the series is exhausted

Implement `TaskScheduling::CalendarProjection.call(task:, range_start:, range_end:)` so it:
- computes visible schedule entries from the recurrence rule
- does not require precreated future rows
- returns `Time` values in the task timezone

Keep the implementation in plain Ruby service objects and avoid callbacks inside the models.

- [ ] **Step 4: Run the specs and confirm they pass**

Run:

```bash
bundle exec rspec spec/services/task_scheduling/next_occurrence_calculator_spec.rb spec/services/task_scheduling/calendar_projection_spec.rb -v
```

Expected: `0 failures, 0 errors`.

- [ ] **Step 5: Commit**

```bash
git add app/services/task_scheduling spec/services/task_scheduling
git commit -m "feat: add recurrence scheduling services"
```

## Task 3: Implement lineage splits, event appends, and next-occurrence advancement

**Files:**
- Create: `app/services/tasks/append_event.rb`
- Create: `app/services/tasks/split_lineage.rb`
- Create: `app/services/tasks/postpone_occurrence.rb`
- Create: `app/services/tasks/advance_occurrence.rb`
- Create: `spec/services/tasks/append_event_spec.rb`
- Create: `spec/services/tasks/split_lineage_spec.rb`
- Create: `spec/services/tasks/postpone_occurrence_spec.rb`
- Create: `spec/services/tasks/advance_occurrence_spec.rb`

- [ ] **Step 1: Write the failing service specs**

```ruby
# spec/services/tasks/split_lineage_spec.rb
require "rails_helper"

RSpec.describe Tasks::SplitLineage do
  it "retires the parent with responsible_changed and creates a child task" do
    parent = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    parent.create_recurrence_rule!(
      rule_type: :weekly,
      weekday: :monday,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    child = described_class.call(
      task: parent,
      end_reason: :responsible_changed,
      responsible_id: 77
    )

    expect(parent.reload).to be_final
    expect(parent.end_reason).to eq("responsible_changed")
    expect(child.parent_task).to eq(parent)
    expect(child.responsible_id).to eq(77)
    expect(child.status).to eq("ongoing")
  end
end
```

```ruby
# spec/services/tasks/postpone_occurrence_spec.rb
require "rails_helper"

RSpec.describe Tasks::PostponeOccurrence do
  it "moves one occurrence without changing the series rule" do
    task = Task.create!(task_kind: :recurring, status: :ongoing, title: "Check email", responsible_id: 42)
    occurrence = task.task_occurrences.create!(scheduled_at: Time.zone.parse("2026-05-11 10:00"), status: :planned)

    described_class.call(occurrence: occurrence, postpone_to: Time.zone.parse("2026-05-12 14:00"), actor_id: 42)

    expect(occurrence.reload.status).to eq("postponed")
    expect(occurrence.postponed_to).to eq(Time.zone.parse("2026-05-12 14:00"))
  end
end
```

```ruby
# spec/services/tasks/advance_occurrence_spec.rb
require "rails_helper"

RSpec.describe Tasks::AdvanceOccurrence do
  it "marks the current occurrence executed and creates the next future occurrence" do
    task = Task.create!(task_kind: :recurring, status: :ongoing, title: "Check email", responsible_id: 42)
    task.create_recurrence_rule!(
      rule_type: :weekly,
      weekday: :monday,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )
    occurrence = task.task_occurrences.create!(scheduled_at: Time.zone.parse("2026-05-11 10:00"), status: :planned)

    expect { described_class.call(occurrence: occurrence, actor_id: 42) }
      .to change { task.task_occurrences.where(status: :planned).count }.by(1)
  end
end
```

- [ ] **Step 2: Run the specs and confirm they fail**

Run:

```bash
bundle exec rspec spec/services/tasks/split_lineage_spec.rb spec/services/tasks/postpone_occurrence_spec.rb spec/services/tasks/advance_occurrence_spec.rb -v
```

Expected: failures for missing service objects and missing transition behavior.

- [ ] **Step 3: Implement the task services**

Implement `Tasks::AppendEvent.call(task:, event_type:, actor_id:, occurrence: nil, payload: {})` so every business write path appends a `TaskEvent` row in one place.

Implement `Tasks::SplitLineage.call(task:, end_reason:, responsible_id: nil, recurrence_rule_attributes: nil)` so it:
- runs in a transaction
- copies the parent task fields into a child task
- sets the parent to final with `status = cancelled`
- stores the reason in `end_reason`
- copies or replaces the recurrence rule onto the child when needed
- returns the new child task

Implement `Tasks::PostponeOccurrence.call(occurrence:, postpone_to:, actor_id:)` so it:
- updates one occurrence only
- records a postpone event
- leaves the recurrence rule untouched

Implement `Tasks::AdvanceOccurrence.call(occurrence:, actor_id:)` so it:
- records execution on the current occurrence
- marks the occurrence executed
- computes the next occurrence from the parent task’s recurrence rule
- inserts exactly one new planned occurrence for the active recurring task
- updates `next_run_at`

Keep the services transactional and keep all history writes append-only.

- [ ] **Step 4: Run the specs and confirm they pass**

Run:

```bash
bundle exec rspec spec/services/tasks/append_event_spec.rb spec/services/tasks/split_lineage_spec.rb spec/services/tasks/postpone_occurrence_spec.rb spec/services/tasks/advance_occurrence_spec.rb -v
```

Expected: `0 failures, 0 errors`.

- [ ] **Step 5: Commit**

```bash
git add app/services/tasks spec/services/tasks
git commit -m "feat: add task lineage and occurrence transitions"
```

## Task 4: Add one end-to-end regression spec for the full business flow

**Files:**
- Create: `spec/integration/hybrid_task_flow_spec.rb`

- [ ] **Step 1: Write the failing end-to-end spec**

```ruby
require "rails_helper"

RSpec.describe "Hybrid recurring task flow", type: :model do
  it "covers creation, one occurrence execution, postponement, responsible change, and schedule change" do
    task = Task.create!(task_kind: :recurring, status: :ongoing, title: "Check email", responsible_id: 42)
    task.create_recurrence_rule!(
      rule_type: :weekly,
      weekday: :monday,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    occurrence = task.task_occurrences.create!(scheduled_at: Time.zone.parse("2026-05-11 10:00"), status: :planned)
    Tasks::PostponeOccurrence.call(occurrence: occurrence, postpone_to: Time.zone.parse("2026-05-12 14:00"), actor_id: 42)

    responsible_child = Tasks::SplitLineage.call(task: task, end_reason: :responsible_changed, responsible_id: 77)
    expect(responsible_child.parent_task).to eq(task)
    expect(task.reload).to be_final
    expect(task.end_reason).to eq("responsible_changed")

    schedule_child = Tasks::SplitLineage.call(
      task: responsible_child,
      end_reason: :schedule_changed,
      recurrence_rule_attributes: {
        rule_type: :weekly,
        weekday: :tuesday,
        execution_time: "14:00",
        timezone: "Europe/Moscow",
        date_start: Date.new(2026, 5, 12)
      }
    )

    expect(schedule_child.parent_task).to eq(responsible_child)
    expect(responsible_child.reload).to be_final
    expect(responsible_child.end_reason).to eq("schedule_changed")
  end
end
```

- [ ] **Step 2: Run the spec and confirm it fails**

Run:

```bash
bundle exec rspec spec/integration/hybrid_task_flow_spec.rb -v
```

Expected: failures until the services and model contracts are wired together cleanly.

- [ ] **Step 3: Fix any integration gaps**

Adjust the model/service boundary only where the integration spec shows a real mismatch:
- missing association wiring
- incorrect enum names
- wrong task retirement behavior
- next-occurrence updates not persisting after transitions

Do not add controllers, routes, or PaperTrail. This slice stays on the domain layer.

- [ ] **Step 4: Run the full targeted suite**

Run:

```bash
bundle exec rspec spec/models spec/services spec/integration/hybrid_task_flow_spec.rb -v
```

Expected: all targeted specs pass.

- [ ] **Step 5: Commit**

```bash
git add spec/integration/hybrid_task_flow_spec.rb
git commit -m "test: cover recurring task lifecycle end to end"
```

## Self-Review Checklist

- The schema tasks cover `tasks`, `recurrence_rules`, `task_occurrences`, and `task_events`.
- The recurrence task covers even/odd day-of-month and even/odd weekday behavior.
- The services task covers append-only history, structural replacement, postponement, and next-occurrence advancement.
- The regression task covers the full business story in one flow.
- There are no placeholders like `TODO`, `TBD`, or “add appropriate validation”.
- The plan does not introduce controllers, routes, or PaperTrail.
- The plan keeps exactly one future scheduled occurrence per active recurring task and preserves historical occurrences.
