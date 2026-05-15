# Task Tracker API Gap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the missing task-tracker API from `tmp/task.md`: authenticated users, task CRUD, delegation accept/decline, tag linking, immutable mandatory tags, non-destructive deactivation, bounded recurrence projection, and per-occurrence state.

**Architecture:** Keep the current hybrid recurrence model where it helps, but expose a practical API contract around users, tasks, tags, and task occurrences. Use Devise if it remains clean in Rails API mode; otherwise use a minimal bearer-token authentication layer while keeping the same `User` model contract. Do not delete business records from the database; use `deactivated_at` and explicit query scopes.

**Tech Stack:** Rails API, PostgreSQL 16, RSpec, Rswag/OpenAPI, Devise preferred for authentication if API-compatible.

---

## File Structure

- `Gemfile` - add Devise or the selected lightweight authentication dependency.
- `app/models/user.rb` - staff identity, roles, Devise modules or token authentication.
- `app/models/task.rb` - rename `title` to `name`, assignment fields, deactivation, lifecycle rules.
- `app/models/tag.rb` - tag validation, system-tag protection, deactivation guard.
- `app/models/task_tag.rb` - task/tag join with non-destructive detach.
- `app/models/recurrence_rule.rb` - required recurrence modes plus documented extensions.
- `app/models/recurrence_rule_date.rb` - explicit-date recurrence entries.
- `app/models/task_occurrence.rb` - per-occurrence state.
- `app/controllers/api/v1/auth_controller.rb` - login/logout/current user if Devise does not provide a clean API controller directly.
- `app/controllers/api/v1/tasks_controller.rb` - task CRUD, list scopes, deactivation.
- `app/controllers/api/v1/task_acceptances_controller.rb` - accept and decline delegated tasks.
- `app/controllers/api/v1/task_tags_controller.rb` - attach/detach tags without deleting join rows.
- `app/controllers/api/v1/tags_controller.rb` - tag listing and non-system tag management.
- `app/controllers/api/v1/task_occurrences_controller.rb` - occurrence-level postpone/skip/execute actions.
- `app/services/task_scheduling/calendar_projection.rb` - bounded window projection.
- `app/services/task_scheduling/next_occurrence_calculator.rb` - next-date generation for supported recurrence modes.
- `db/migrate/20260514000002_create_users.rb` - users table with auth fields, role, name, and last name.
- `db/migrate/20260514000003_update_tasks_for_public_api.rb` - rename `title` to `name`; add `completion_date`, `creator_id`, nullable `responsible_id`, `delegated_user_id`, `accepted_at`, `cancellation_reason`, and `deactivated_at`.
- `db/migrate/20260514000004_create_tags.rb` - tags table with `is_system_tag` and `deactivated_at`.
- `db/migrate/20260514000005_create_task_tags.rb` - many-to-many join table with `deactivated_at`.
- `db/migrate/20260514000006_create_recurrence_rule_dates.rb` - explicit recurrence dates.
- `db/migrate/20260514000007_add_tag_immutability_trigger.rb` - PostgreSQL protection for seeded tags.
- `db/seeds.rb` - seed users for local development if useful and seed the mandatory tags.
- `config/routes.rb` - API routes.
- `spec/models/user_spec.rb` - auth and role validation.
- `spec/models/task_spec.rb` - assignment invariant, statuses, deactivation, final immutability.
- `spec/models/tag_spec.rb` - system tag immutability.
- `spec/models/task_tag_spec.rb` - non-destructive attach/detach constraints.
- `spec/models/recurrence_rule_date_spec.rb` - specific-date recurrence.
- `spec/requests/api/v1/auth_spec.rb` - login/current-user behavior.
- `spec/requests/api/v1/tasks_spec.rb` - CRUD, role visibility, list scopes, deactivation.
- `spec/requests/api/v1/task_acceptances_spec.rb` - accept and decline behavior.
- `spec/requests/api/v1/tags_spec.rb` - tag API behavior.
- `spec/requests/api/v1/task_occurrences_spec.rb` - occurrence-level state actions.
- `spec/requests/api/v1/swagger_spec.rb` - OpenAPI generation coverage.
- `spec/services/task_scheduling/next_occurrence_calculator_spec.rb` - recurrence modes.
- `spec/services/task_scheduling/calendar_projection_spec.rb` - windowed projection.
- `README.md` - assumptions, startup, auth flow, recurrence behavior, and non-deletion policy.
- `swagger/v1/swagger.json` - generated OpenAPI output.
- `HISTORY.md` - concise task decision log.

## Task 1: Add Authenticated Users

**Files:**
- Modify: `Gemfile`
- Create: `app/models/user.rb`
- Create: `db/migrate/20260514000002_create_users.rb`
- Create: `spec/models/user_spec.rb`
- Create: `spec/requests/api/v1/auth_spec.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing specs**

```ruby
require "rails_helper"

RSpec.describe User, type: :model do
  it "requires staff identity fields" do
    user = described_class.new(
      email: "doctor@example.test",
      password: "password123",
      role: :doctor,
      name: "Ivan",
      last_name: "Petrov"
    )

    expect(user).to be_valid
    expect(described_class.roles.keys).to match_array(%w[administrator doctor nurse])
  end
end
```

```ruby
require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  it "authenticates a user and returns a bearer token or authenticated session payload" do
    User.create!(
      email: "doctor@example.test",
      password: "password123",
      role: :doctor,
      name: "Ivan",
      last_name: "Petrov"
    )

    post "/api/v1/auth/login", params: { email: "doctor@example.test", password: "password123" }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to include("user")
  end
end
```

- [ ] **Step 2: Run and confirm failure**

Run:

```bash
bundle exec rspec spec/models/user_spec.rb spec/requests/api/v1/auth_spec.rb -v
```

Expected: missing dependency/model/controller failures.

- [ ] **Step 3: Implement auth**

Add Devise and configure it for API requests if it stays straightforward. If Devise requires session-heavy behavior, implement a minimal bearer-token fallback with the same `User` fields and authenticated request helper.

Required model contract:
- `role` enum: `administrator`, `doctor`, `nurse`
- `name` and `last_name` not null
- index on `[name, last_name]`
- authenticated task mutations require a current user
- administrators can view every task
- doctors and nurses can view only tasks connected by `creator_id`, `responsible_id`, or `delegated_user_id`

- [ ] **Step 4: Run and confirm pass**

Run:

```bash
bundle exec rspec spec/models/user_spec.rb spec/requests/api/v1/auth_spec.rb -v
```

Expected: `0 failures, 0 errors`.

## Task 2: Align Task Model With Public API

**Files:**
- Modify: `app/models/task.rb`
- Create: `db/migrate/20260514000003_update_tasks_for_public_api.rb`
- Modify: `spec/models/task_spec.rb`

- [ ] **Step 1: Write failing model specs**

```ruby
require "rails_helper"

RSpec.describe Task, type: :model do
  it "allows pending delegated tasks without a responsible user" do
    creator = User.create!(email: "admin@example.test", password: "password123", role: :administrator, name: "Anna", last_name: "Admin")
    delegate = User.create!(email: "doctor@example.test", password: "password123", role: :doctor, name: "Ivan", last_name: "Petrov")

    task = described_class.new(
      task_kind: :one_time,
      status: :pending_acceptance,
      name: "Review lab results",
      creator: creator,
      delegated_user: delegate,
      responsible: nil
    )

    expect(task).to be_valid
  end

  it "rejects orphan tasks with no creator, responsible, or delegated user" do
    task = described_class.new(task_kind: :one_time, status: :draft, name: "Orphan task")

    expect(task).not_to be_valid
    expect(task.errors[:base]).to include("must have a creator, responsible user, or delegated user")
  end
end
```

- [ ] **Step 2: Run and confirm failure**

Run:

```bash
bundle exec rspec spec/models/task_spec.rb -v
```

Expected: missing `name`, user associations, and invariant failures.

- [ ] **Step 3: Implement model changes**

Change task storage and associations:
- rename `tasks.title` to `tasks.name`
- add `completion_date`
- add `creator_id`
- make `responsible_id` nullable
- add `delegated_user_id`
- add `accepted_at`
- add `cancellation_reason`
- add `deactivated_at`
- add `end_reason = declined`
- add foreign keys to `users`
- add a database check constraint requiring at least one of `creator_id`, `responsible_id`, or `delegated_user_id`

Keep statuses:
- `draft`
- `pending_acceptance`
- `ongoing`
- `completed`
- `cancelled`

- [ ] **Step 4: Run and confirm pass**

Run:

```bash
bundle exec rspec spec/models/task_spec.rb -v
```

Expected: `0 failures, 0 errors`.

## Task 3: Add Task CRUD, Deactivation, And List Scopes

**Files:**
- Create: `app/controllers/api/v1/tasks_controller.rb`
- Create: `spec/requests/api/v1/tasks_spec.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing request spec**

```ruby
require "rails_helper"

RSpec.describe "Api::V1::Tasks", type: :request do
  it "creates, lists, and deactivates tasks for the authenticated user" do
    user = User.create!(email: "doctor@example.test", password: "password123", role: :doctor, name: "Ivan", last_name: "Petrov")
    auth_headers = auth_headers_for(user)

    post "/api/v1/tasks", params: {
      task: {
        name: "Morning rounds",
        description: "Check assigned patients",
        completion_date: "2026-05-15T12:00:00+03:00",
        status: "ongoing"
      }
    }, headers: auth_headers

    expect(response).to have_http_status(:created)
    task_id = JSON.parse(response.body).dig("data", "id")

    get "/api/v1/tasks", params: { scope: "mine", from: "2026-05-14", to: "2026-05-16" }, headers: auth_headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("data", 0, "attributes", "name")).to eq("Morning rounds")

    delete "/api/v1/tasks/#{task_id}", headers: auth_headers
    expect(response).to have_http_status(:no_content)
    expect(Task.find(task_id).deactivated_at).to be_present
  end

  it "allows administrators to list every task and restricts doctors to bonded tasks" do
    admin = User.create!(email: "admin@example.test", password: "password123", role: :administrator, name: "Anna", last_name: "Admin")
    doctor = User.create!(email: "doctor@example.test", password: "password123", role: :doctor, name: "Ivan", last_name: "Petrov")
    other = User.create!(email: "other@example.test", password: "password123", role: :doctor, name: "Petr", last_name: "Other")

    visible = Task.create!(task_kind: :one_time, status: :ongoing, name: "Visible task", responsible: doctor)
    hidden = Task.create!(task_kind: :one_time, status: :ongoing, name: "Hidden task", responsible: other)

    get "/api/v1/tasks", headers: auth_headers_for(admin)
    expect(JSON.parse(response.body)["data"].map { |row| row["id"] }).to include(visible.id.to_s, hidden.id.to_s)

    get "/api/v1/tasks", headers: auth_headers_for(doctor)
    visible_ids = JSON.parse(response.body)["data"].map { |row| row["id"] }
    expect(visible_ids).to include(visible.id.to_s)
    expect(visible_ids).not_to include(hidden.id.to_s)
  end
end
```

- [ ] **Step 2: Run and confirm failure**

Run:

```bash
bundle exec rspec spec/requests/api/v1/tasks_spec.rb -v
```

Expected: missing controller/routes/auth helper failures.

- [ ] **Step 3: Implement task endpoints**

Create:
- `GET /api/v1/tasks`
- `GET /api/v1/tasks/:id`
- `POST /api/v1/tasks`
- `PATCH /api/v1/tasks/:id`
- `DELETE /api/v1/tasks/:id`

List scopes:
- `mine`: `responsible_id = current_user.id`
- `delegated_to_me`: `delegated_user_id = current_user.id AND status = pending_acceptance`
- `created_by_me`: `creator_id = current_user.id`

Authorization boundary:
- administrators can list and inspect all tasks
- doctors and nurses can list and inspect only tasks bonded to them through `creator_id`, `responsible_id`, or `delegated_user_id`
- apply the boundary before applying optional scopes or filters

Removal behavior:
- set `deactivated_at`
- do not delete rows
- exclude deactivated rows from default list responses

- [ ] **Step 4: Run and confirm pass**

Run:

```bash
bundle exec rspec spec/requests/api/v1/tasks_spec.rb -v
```

Expected: `0 failures, 0 errors`.

## Task 4: Add Accept And Decline Actions

**Files:**
- Create: `app/controllers/api/v1/task_acceptances_controller.rb`
- Create: `spec/requests/api/v1/task_acceptances_spec.rb`
- Modify: `app/models/task_event.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing request specs**

```ruby
require "rails_helper"

RSpec.describe "Api::V1::TaskAcceptances", type: :request do
  it "accepts a delegated task" do
    creator = User.create!(email: "admin@example.test", password: "password123", role: :administrator, name: "Anna", last_name: "Admin")
    delegate = User.create!(email: "doctor@example.test", password: "password123", role: :doctor, name: "Ivan", last_name: "Petrov")
    task = Task.create!(task_kind: :one_time, status: :pending_acceptance, name: "Review lab results", creator: creator, delegated_user: delegate)

    post "/api/v1/tasks/#{task.id}/accept", headers: auth_headers_for(delegate)

    expect(response).to have_http_status(:ok)
    expect(task.reload.responsible).to eq(delegate)
    expect(task.delegated_user).to be_nil
    expect(task.status).to eq("ongoing")
    expect(task.accepted_at).to be_present
  end

  it "declines a delegated task" do
    creator = User.create!(email: "admin2@example.test", password: "password123", role: :administrator, name: "Anna", last_name: "Admin")
    delegate = User.create!(email: "doctor2@example.test", password: "password123", role: :doctor, name: "Ivan", last_name: "Petrov")
    task = Task.create!(task_kind: :one_time, status: :pending_acceptance, name: "Review lab results", creator: creator, delegated_user: delegate)

    post "/api/v1/tasks/#{task.id}/decline", headers: auth_headers_for(delegate)

    expect(response).to have_http_status(:ok)
    expect(task.reload.status).to eq("cancelled")
    expect(task.end_reason).to eq("declined")
    expect(task.cancellation_reason).to eq("was declined")
    expect(task.cancelled_at).to be_present
  end
end
```

- [ ] **Step 2: Run and confirm failure**

Run:

```bash
bundle exec rspec spec/requests/api/v1/task_acceptances_spec.rb -v
```

Expected: missing routes/controller/event enum failures.

- [ ] **Step 3: Implement accept and decline**

Rules:
- only `delegated_user_id` can accept or decline
- accept sets `responsible_id`, clears `delegated_user_id`, sets `status = ongoing`, sets `accepted_at`
- decline sets `status = cancelled`, `end_reason = declined`, `cancellation_reason = "was declined"`, sets `cancelled_at`
- append audit events for both actions

- [ ] **Step 4: Run and confirm pass**

Run:

```bash
bundle exec rspec spec/requests/api/v1/task_acceptances_spec.rb -v
```

Expected: `0 failures, 0 errors`.

## Task 5: Add Tags And Non-Destructive Attach/Detach

**Files:**
- Create: `app/models/tag.rb`
- Create: `app/models/task_tag.rb`
- Create: `app/controllers/api/v1/tags_controller.rb`
- Create: `app/controllers/api/v1/task_tags_controller.rb`
- Modify: `db/seeds.rb`
- Create: `db/migrate/20260514000004_create_tags.rb`
- Create: `db/migrate/20260514000005_create_task_tags.rb`
- Create: `db/migrate/20260514000007_add_tag_immutability_trigger.rb`
- Create: `spec/requests/api/v1/tags_spec.rb`
- Create: `spec/models/tag_spec.rb`
- Create: `spec/models/task_tag_spec.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing specs**

```ruby
require "rails_helper"

RSpec.describe Tag, type: :model do
  it "prevents system tags from being deactivated" do
    tag = described_class.create!(name: "Отчётность", description: "Seeded", is_system_tag: true)

    expect(tag.update(deactivated_at: Time.current)).to be(false)
    expect(tag.errors[:base]).to include("system tags cannot be changed")
  end
end
```

```ruby
require "rails_helper"

RSpec.describe TaskTag, type: :model do
  it "detaches without deleting the join row" do
    user = User.create!(email: "doctor@example.test", password: "password123", role: :doctor, name: "Ivan", last_name: "Petrov")
    task = Task.create!(task_kind: :one_time, status: :ongoing, name: "Morning rounds", responsible: user)
    tag = Tag.create!(name: "custom", description: "Custom", is_system_tag: false)
    task_tag = described_class.create!(task: task, tag: tag)

    task_tag.update!(deactivated_at: Time.current)

    expect(described_class.find(task_tag.id)).to be_present
    expect(task_tag.reload.deactivated_at).to be_present
  end
end
```

- [ ] **Step 2: Run and confirm failure**

Run:

```bash
bundle exec rspec spec/models/tag_spec.rb spec/models/task_tag_spec.rb spec/requests/api/v1/tags_spec.rb -v
```

Expected: missing models/routes/trigger failures.

- [ ] **Step 3: Implement tags**

Rules:
- seed `Отчётность`, `Операции`, `Звонок` as `is_system_tag = true`
- system tags cannot be renamed, deactivated, or deleted
- PostgreSQL trigger enforces the same protection against direct SQL
- detaching a tag from a task sets `task_tags.deactivated_at`
- attaching a previously detached tag reactivates the join row

- [ ] **Step 4: Run and confirm pass**

Run:

```bash
bundle exec rspec spec/models/tag_spec.rb spec/models/task_tag_spec.rb spec/requests/api/v1/tags_spec.rb -v
```

Expected: `0 failures, 0 errors`.

## Task 6: Add Required Recurrence Modes And Document Extensions

**Files:**
- Modify: `app/models/recurrence_rule.rb`
- Create: `app/models/recurrence_rule_date.rb`
- Create: `db/migrate/20260514000006_create_recurrence_rule_dates.rb`
- Modify: `app/services/task_scheduling/next_occurrence_calculator.rb`
- Modify: `app/services/task_scheduling/calendar_projection.rb`
- Create: `spec/models/recurrence_rule_date_spec.rb`
- Modify: `spec/models/recurrence_rule_spec.rb`
- Modify: `spec/services/task_scheduling/next_occurrence_calculator_spec.rb`
- Modify: `spec/services/task_scheduling/calendar_projection_spec.rb`

- [ ] **Step 1: Write failing recurrence specs**

```ruby
require "rails_helper"

RSpec.describe RecurrenceRuleDate, type: :model do
  it "stores explicit schedule dates for specific-date recurrence" do
    user = User.create!(email: "doctor@example.test", password: "password123", role: :doctor, name: "Ivan", last_name: "Petrov")
    task = Task.create!(task_kind: :recurring, status: :ongoing, name: "Inventory", responsible: user)
    rule = task.build_recurrence_rule(
      rule_type: :specific_dates,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )
    rule.recurrence_rule_dates.build(run_date: Date.new(2026, 5, 20))

    expect(rule).to be_valid
  end
end
```

- [ ] **Step 2: Run and confirm failure**

Run:

```bash
bundle exec rspec spec/models/recurrence_rule_date_spec.rb spec/services/task_scheduling/next_occurrence_calculator_spec.rb spec/services/task_scheduling/calendar_projection_spec.rb -v
```

Expected: missing model and unsupported specific-date recurrence failures.

- [ ] **Step 3: Implement recurrence behavior**

Required assignment modes:
- every N days
- monthly on a fixed day of month
- specific dates
- even/odd days of month

Allowed extensions:
- weekday parity
- yearly schedules
- other existing branch modes, if documented and covered

Projection rules:
- project only inside `[from, to]`
- stop at `date_end` when present
- do not generate database rows beyond the current actionable occurrence and historical exceptions

- [ ] **Step 4: Run and confirm pass**

Run:

```bash
bundle exec rspec spec/models/recurrence_rule_date_spec.rb spec/services/task_scheduling/next_occurrence_calculator_spec.rb spec/services/task_scheduling/calendar_projection_spec.rb -v
```

Expected: `0 failures, 0 errors`.

## Task 7: Add Occurrence-Level Actions

**Files:**
- Modify: `app/models/task_occurrence.rb`
- Create: `app/controllers/api/v1/task_occurrences_controller.rb`
- Create: `spec/requests/api/v1/task_occurrences_spec.rb`
- Modify: `app/services/tasks/postpone_occurrence.rb`
- Modify: `app/services/tasks/advance_occurrence.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing request spec**

```ruby
require "rails_helper"

RSpec.describe "Api::V1::TaskOccurrences", type: :request do
  it "postpones a single occurrence without changing the series" do
    user = User.create!(email: "doctor@example.test", password: "password123", role: :doctor, name: "Ivan", last_name: "Petrov")
    task = Task.create!(task_kind: :recurring, status: :ongoing, name: "Daily call", responsible: user)
    occurrence = task.task_occurrences.create!(scheduled_at: Time.zone.parse("2026-05-15 10:00"), status: "planned")

    post "/api/v1/task_occurrences/#{occurrence.id}/postpone",
      params: { postponed_to: "2026-05-15T12:00:00+03:00" },
      headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    expect(occurrence.reload.status).to eq("postponed")
  end
end
```

- [ ] **Step 2: Run and confirm failure**

Run:

```bash
bundle exec rspec spec/requests/api/v1/task_occurrences_spec.rb -v
```

Expected: missing controller/action failures.

- [ ] **Step 3: Implement per-occurrence actions**

Actions:
- postpone one occurrence
- mark one occurrence executed
- skip one occurrence

Rules:
- actions require authenticated responsible user or delegated user where applicable
- mutation is scoped to one occurrence
- sibling occurrences in the same series are not mutated

- [ ] **Step 4: Run and confirm pass**

Run:

```bash
bundle exec rspec spec/requests/api/v1/task_occurrences_spec.rb -v
```

Expected: `0 failures, 0 errors`.

## Task 8: Document Assumptions And Generate Swagger

**Files:**
- Modify: `README.md`
- Modify: `spec/swagger_helper.rb`
- Modify: `config/initializers/rswag_api.rb`
- Modify: `config/initializers/rswag_ui.rb`
- Create: `spec/requests/api/v1/swagger_spec.rb`
- Modify: `HISTORY.md`

- [ ] **Step 1: Add Swagger coverage**

Document:
- auth/login
- task CRUD
- task accept/decline
- task deactivation behavior
- tag attach/detach
- recurrence fields
- occurrence actions

- [ ] **Step 2: Update README**

Document:
- local startup
- auth assumptions and request flow
- status semantics
- delegation accept/decline
- non-deletion policy via `deactivated_at`
- recurrence required modes and extensions
- system tag immutability

- [ ] **Step 3: Regenerate Swagger**

Run:

```bash
bundle exec rails rswag:specs:swaggerize
```

Expected: `swagger/v1/swagger.json` is generated.

- [ ] **Step 4: Update history**

Append one short `HISTORY.md` entry summarizing the implemented API assumptions and changed files.
