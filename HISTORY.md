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
