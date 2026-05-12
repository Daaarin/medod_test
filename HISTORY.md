# History

This file is the local running log for conversations and task decisions.

Format for entries:

- `YYYY-MM-DD` - short summary of the request or decision
- Optional: files changed, assumptions, follow-up items

- `2026-05-09` - Added repo-local agent guidance to record concise conversation and task summaries in `HISTORY.md`; created the initial `HISTORY.md` log file.
- `2026-05-09` - Added Graphify support for Codex: installed repo graphify instructions in `AGENTS.md`, created the initial `graphify-out/` graph, installed the git hooks, and added a README note plus ignore rule for generated graph output.
- `2026-05-09` - Completed the Docker Compose dev stack for a Rails API, React/Vite frontend, PostgreSQL 16, and Rswag Swagger scaffolding; added CORS, database env handling, and a starter documented `/up` endpoint.
- `2026-05-09` - Fixed the Docker dev image build failure by adding `libyaml-dev` and `pkg-config` so Ruby's `psych` native extension can compile during `bundle install`.
- `2026-05-09` - Verified the backend container builds successfully after the Dockerfile.dev fix.
- `2026-05-10` - Added a local pre-commit git hook that runs `bundle exec rubocop -A` on staged Ruby files and restages RuboCop changes automatically.
- `2026-05-12` - Finalized the hybrid recurring-task domain design: single-parent lineage, immutable event history, `responsible` naming, `end_reason` for retired nodes, parity-based recurrence selectors, and only one persisted future occurrence per active recurring task; wrote the implementation plan to `docs/superpowers/plans/2026-05-12-hybrid-recurring-task-model.md`.
- `2026-05-12` - Implemented Task 1 of the hybrid recurring-task model: added migrations for `tasks`, `recurrence_rules`, `task_occurrences`, and `task_events`; created core model contracts and focused model specs; ran the model specs in the backend container against the test DB. Note: RSpec needed a temporary fixture-path compatibility shim because `spec/rails_helper.rb` still uses the older `fixture_path=` API.
- `2026-05-12` - Implemented Task 2 recurrence math: added `TaskScheduling::NextOccurrenceCalculator` and `TaskScheduling::CalendarProjection` plus focused specs for one-time, every_n_days, every_n_months, every_n_years, day_of_month_parity, and weekday_parity scheduling. Verified with targeted rspec runs using the local fixture-path shim and the existing PostgreSQL instance under the `exsamption` user.
- `2026-05-12` - Followed up on Task 2 review feedback by making every_n_days DST-safe, tightening recurrence-rule validation for malformed configs, selector ranges, and date-window ordering, and expanding calendar projection coverage for every_n_months, every_n_years, day_of_month_parity, weekday_parity, and DST boundary cases.
- `2026-05-12` - Reviewed the current recurrence scheduling working-tree changes for recurrence math, time zone handling, projection termination, validation contract, and test coverage; targeted specs pass with the temporary fixture-path shim.
- `2026-05-12` - Implemented Task 3 lifecycle services: added `Tasks::AppendEvent`, `Tasks::SplitLineage`, `Tasks::PostponeOccurrence`, and `Tasks::AdvanceOccurrence` with focused service specs; final-state writes use `update_columns` so the existing immutability callback does not block the required terminal transitions. Verified the targeted service specs against the local `exsamption` PostgreSQL role using the temporary RSpec fixture-path shim.
- `2026-05-12` - Reviewed commit `1242a5a` for task lineage and occurrence lifecycle services; noted risks around split occurrence handling, missing split audit events, transition guards, and test coverage. Targeted specs could not run locally because the configured PostgreSQL `postgres` role is unavailable.
- `2026-05-12` - Fixed the Task 3 split/postpone/advance follow-up gaps: `SplitLineage` now locks the parent, appends split/created audit rows, transfers or recreates the planned occurrence, and finalizes the parent with `next_run_at` cleared; `PostponeOccurrence` and `AdvanceOccurrence` now lock and validate source state before mutating. Updated the service specs plus `TaskEvent` coverage, ran the targeted RSpec slice with the `exsamption` DB role and fixture-path shim, and refreshed `graphify-out/`. Assumption: split audit rows can fall back to the parent responsible id when no explicit `actor_id` is provided.
