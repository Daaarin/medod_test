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
- `2026-05-14` - Added a compose-backed VS Code devcontainer for the existing backend/frontend/PostgreSQL stack; it bootstraps `.env` from `.env.example` on first launch and reuses the current Docker Compose services.
