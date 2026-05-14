# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Graphify

This repo is set up for Graphify with Codex.

- Repo instructions live in `AGENTS.md`.
- The initial graph is generated in `graphify-out/`.
- Rebuild it with `graphify update .` after code changes.
- Check `graphify-out/GRAPH_REPORT.md` for a compact architecture summary before answering codebase questions.

## Local Dev Stack

The compose setup now provides:

- Rails API backend on port `3000`
- React + Vite admin frontend on port `5173`
- PostgreSQL 16 on port `5432`
- Swagger/OpenAPI docs mounted at `/api-docs` in development and test

Start it with:

```bash
docker compose up --build
```

The frontend talks to the Rails API at `http://localhost:3000`, and the `/up` route is documented with Rswag as a starter endpoint.

The stack requires a local `.env` file. Copy the template before starting Docker or opening the Dev Container:

```bash
cp .env.example .env
```

## Dev Container

Open the repository in VS Code with Dev Containers to launch the same backend, frontend, and PostgreSQL stack inside Docker.

- The container configuration lives in [.devcontainer/devcontainer.json](.devcontainer/devcontainer.json).
- Create `.env` first, or the Compose-backed Dev Container will fail fast when it starts.
- The backend service is the workspace container; the frontend and database services start alongside it.
