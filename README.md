# Medods Test API

Rails API for authenticated medical staff tasks with delegation, recurrence,
occurrence-level actions, and non-destructive tag/task removal.

## Local Startup

Use Docker for the full local stack:

```bash
cp .env.example .env
docker compose up --build
```

The stack requires a local `.env` file. Copy the template before starting
Docker or opening the Dev Container.

The compose setup provides:

- Rails API backend on port `3000`
- React + Vite admin frontend on port `5173`
- PostgreSQL 16 on port `5432`
- Swagger/OpenAPI docs at `http://localhost:3000/api-docs`

For local host-based Rails commands, this machine uses the OS PostgreSQL user:

```bash
DATABASE_USERNAME=exsamption DATABASE_PASSWORD= bin/rails db:prepare
bundle exec rspec
bundle exec rubocop --cache false
```

## Auth

Auth is first-party bearer-token auth:

- `POST /api/v1/auth/login` accepts `email` and `password`.
- The response includes a bearer token.
- Send protected requests with `Authorization: Bearer <token>`.
- `GET /api/v1/auth/me` returns the current authenticated user.

User roles are `administrator`, `doctor`, and `nurse`.

## Task Access

Administrators can view all non-deactivated tasks. Other roles can view only
tasks bonded to them by one of:

- `creator_id`
- `responsible_id`
- `delegated_user_id`

Generic task CRUD intentionally does not expose workflow transitions as raw
mass-assignment. Delegation acceptance/decline and occurrence actions use
dedicated endpoints.

## Task Lifecycle

Task statuses:

- `draft`
- `pending_acceptance`
- `ongoing`
- `completed`
- `cancelled`

Delegated tasks start as `pending_acceptance` with `delegated_user_id` set and
nullable `responsible_id`. The delegated user can:

- `POST /api/v1/tasks/:task_id/accept` to become responsible. This sets
  `responsible_id`, clears `delegated_user_id`, sets `status = ongoing`, and
  records `accepted_at`.
- `POST /api/v1/tasks/:task_id/decline` to cancel the delegated task. This sets
  `status = cancelled`, `end_reason = declined`, `cancellation_reason = "was declined"`,
  and `cancelled_at`.

Both actions append audit events and re-check state under a row lock.

## Non-Deletion Policy

Removal behavior deactivates records and does not remove database rows.

- Task deletion sets `tasks.deactivated_at`.
- Tag deletion sets `tags.deactivated_at`.
- Task/tag detach sets `task_tags.deactivated_at`.
- Re-attaching a detached tag reactivates the existing `task_tags` row.

Business-model destroy callbacks block Rails hard deletes. PostgreSQL triggers
also block direct `DELETE`/`TRUNCATE` for `tags` and `task_tags`, and block
direct system-tag updates.

## Tags

Seeded system tags:

- `Отчётность`
- `Операции`
- `Звонок`

System tags have `is_system_tag = true` and cannot be renamed, deactivated, or
deleted through Rails or direct SQL.

## Recurrence

Supported assignment-required modes:

- every N days
- monthly on a fixed day of month
- specific dates via `recurrence_rule_dates`
- even/odd days of month

Documented extensions retained by this implementation:

- weekday parity
- every N months
- every N years

Projection is bounded to the requested `[from, to]` range. `date_end` stops
future generation. Specific-date recurrence uses explicit `run_date` rows and
does not create occurrence rows during projection.

## Occurrence Actions

Occurrence-level endpoints mutate one occurrence at a time:

- `POST /api/v1/task_occurrences/:id/postpone`
- `POST /api/v1/task_occurrences/:id/execute`
- `POST /api/v1/task_occurrences/:id/skip`

Allowed writers are administrators, task creators, and task responsible users.
Delegated-only pending users stay read-only until they accept the task.

## Swagger

Swagger/OpenAPI JSON is generated at `swagger/v1/swagger.json`.
The local pre-commit hook regenerates it automatically when API or Swagger
sources change and restages the result before the commit completes.

The Rails command form for `rswag:specs:swaggerize` is not exposed in this
setup. Generate the file with:

```bash
SWAGGER_DRY_RUN=0 bundle exec rspec spec/requests/api/v1/swagger_spec.rb --format Rswag::Specs::SwaggerFormatter
```

## Graphify

This repo is set up for Graphify with Codex.

- Repo instructions live in `AGENTS.md`.
- The initial graph is generated in `graphify-out/`.
- Rebuild it with `graphify update .` after code changes.
- Check `graphify-out/GRAPH_REPORT.md` for a compact architecture summary before answering codebase questions.

The frontend talks to the Rails API at `http://localhost:3000`.

## Dev Container

Open the repository in VS Code with Dev Containers to launch the same backend,
frontend, and PostgreSQL stack inside Docker.

- The container configuration lives in [.devcontainer/devcontainer.json](/Users/exsamption/projects/medods_test_api/.devcontainer/devcontainer.json).
- Create `.env` first, or the Compose-backed Dev Container will fail fast when
  it starts.
- The backend service is the workspace container; the frontend and database
  services start alongside it.
