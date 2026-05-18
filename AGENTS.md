# Repo Agent Instructions

- Keep a concise local record of user conversations and task decisions in `HISTORY.md` at the repository root.
- For each meaningful interaction or task update, append a dated entry with:
  - the user request or topic
  - key decisions or assumptions
  - files changed or next steps
- Keep entries brief and practical. Do not store secrets, credentials, or full verbatim transcripts unless the user explicitly asks for that.
- Update `HISTORY.md` as part of completing the work, or sooner if a milestone decision needs to be preserved.
- When changing API behavior, routes, request parameters, or response payloads, update `spec/requests/api/v1/swagger_spec.rb` in the same task and regenerate `swagger/v1/swagger.json` before finishing.
- Treat Swagger drift as a release bug: do not leave API changes without matching Swagger updates unless the user explicitly asks to defer them.

## graphify

This project has a graphify knowledge graph at graphify-out/.

Rules:
- Before answering architecture or codebase questions, read graphify-out/GRAPH_REPORT.md for god nodes and community structure
- If graphify-out/wiki/index.md exists, navigate it instead of reading raw files
- After modifying code files in this session, run `graphify update .` to keep the graph current (AST-only, no API cost)
