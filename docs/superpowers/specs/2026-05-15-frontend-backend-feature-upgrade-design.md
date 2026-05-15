# Frontend Backend Feature Upgrade Design

## Summary
Upgrade the current React/Vite frontend from a placeholder admin shell into a hybrid staff operations app with admin capabilities layered in by role.

The backend now exposes authenticated task workflows: task CRUD, visibility rules, delegation acceptance and decline, tags, recurrence rules, occurrence projection, occurrence actions, and API documentation. The frontend should make those workflows usable without splitting the product into separate staff and admin apps.

## Current State
The frontend currently has:
- a shell layout with sidebar navigation
- placeholder `Overview`, `Users`, `Activity`, and `Settings` routes
- a health check query against `/up`
- no authentication flow
- no task, tag, recurrence, delegation, or occurrence UI

The backend currently has public API routes for:
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/tasks`
- `GET /api/v1/tasks/:id`
- `POST /api/v1/tasks`
- `PATCH /api/v1/tasks/:id`
- `DELETE /api/v1/tasks/:id`
- `POST /api/v1/tasks/:task_id/accept`
- `POST /api/v1/tasks/:task_id/decline`
- `GET /api/v1/tags`
- `POST /api/v1/tags`
- `PATCH /api/v1/tags/:id`
- `DELETE /api/v1/tags/:id`
- `POST /api/v1/tasks/:task_id/tags/:tag_id`
- `DELETE /api/v1/tasks/:task_id/tags/:tag_id`
- `POST /api/v1/task_occurrences/:id/postpone`
- `POST /api/v1/task_occurrences/:id/execute`
- `POST /api/v1/task_occurrences/:id/skip`
- Swagger UI under `/api-docs` in development and test

## Design Direction
Use a hybrid role-based app.

Core rule:
- doctors, nurses, and administrators all use the same task workspace.
- administrators get additional controls and global visibility.
- doctors and nurses only see tasks connected to them by backend authorization rules.

This avoids duplicating frontend modules while still supporting admin workflows. The app should feel like an operational task tool first, with admin affordances available when the authenticated user role is `administrator`.

## Navigation
Replace the placeholder navigation with task-centered routes:
- `Tasks` - main task workspace and filters.
- `Delegated` - focused view for pending delegated tasks and accept/decline decisions.
- `Calendar` - date-window task and occurrence projection view.
- `Tags` - tag catalog and tag maintenance.
- `Admin` - administrator-only operational area.

`Admin` should be hidden for non-admin roles. If a non-admin user reaches the route manually, the frontend should show an access-denied state without calling unsupported admin-only APIs.

The current health/API docs affordances belong in the admin area, not the primary staff workflow.

## Auth And Session
Add a session layer around the API:
- login form posts `email` and `password` to `/api/v1/auth/login`.
- store the returned bearer token in client-side storage.
- load `/api/v1/auth/me` on app start when a token exists.
- expose current user fields: `id`, `email`, `role`, `name`, `last_name`.
- clear the session and redirect to login on 401 responses.
- show a forbidden state on 403 responses.

All authenticated API requests should go through one `apiClient` helper that attaches `Authorization: Bearer <token>`, parses JSON, and normalizes error responses from `{ error }` and `{ errors }`.

## Task Workspace
The main task workspace should support the backend list contract:
- `scope`: `mine`, `delegated_to_me`, `created_by_me`
- task lifecycle `status`: `draft`, `pending_acceptance`, `ongoing`, `completed`, `cancelled`
- date range filters: `from`, `to`
- occurrence status filter: `planned`, `postponed`, `executed`, `skipped`, `superseded`, `cancelled`

Task rows should show:
- name
- description preview
- lifecycle status
- task kind
- creator, responsible user, and delegated user ids until the backend exposes richer user lookup data
- tags only when the backend includes attached tag data in task payloads
- occurrence data when a date-filtered response includes `attributes.occurrence`
- projected occurrence marker when `occurrence.projected = true`

Projected occurrence rows are read-only for occurrence actions because the backend action endpoints require a persisted occurrence id.

## Task Detail And Editing
Task detail should support:
- viewing the full task payload
- creating one-time tasks
- creating recurring tasks
- updating editable fields currently accepted by the backend: `name`, `description`, `completion_date`
- soft deactivation through `DELETE /api/v1/tasks/:id`
- attaching and detaching tags

Creation should support:
- self-assigned tasks with `assign_to_self`
- delegated tasks with `delegated_user_id`
- one-time scheduling with `completion_date`, `first_run_at`, or `next_run_at` as applicable
- recurring scheduling through nested `recurrence_rule_attributes`

The frontend should not expose fields the backend update endpoint does not currently accept, such as changing assignees or recurrence rules after creation, unless the backend contract is expanded first.

Until a users list endpoint exists, delegated task creation should accept a numeric `delegated_user_id` rather than presenting a searchable staff picker.

## Delegation Flow
The `Delegated` route should default to:
- `GET /api/v1/tasks?scope=delegated_to_me&status=pending_acceptance`

Each delegated task should offer:
- Accept: `POST /api/v1/tasks/:task_id/accept`
- Decline: `POST /api/v1/tasks/:task_id/decline`

After a successful transition, invalidate task queries and show the updated task state. If the backend returns `422`, show the server-provided reason, such as stale state or task no longer being pending acceptance.

## Recurrence UI
The recurrence form should support the assignment-required and backend-supported modes:
- every N days
- every N months on a fixed day of month
- specific dates
- even or odd days of month

It may also expose backend extensions when implemented and documented:
- every N years
- weekday parity

The form should collect:
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
- `recurrence_rule_dates_attributes`

Only fields relevant to the selected mode should be enabled. The frontend should perform basic required-field validation before submitting, but backend validation remains authoritative.

## Occurrence Actions
For persisted occurrences, expose actions based on occurrence status:
- Postpone: `POST /api/v1/task_occurrences/:id/postpone` with `postponed_to`
- Execute: `POST /api/v1/task_occurrences/:id/execute`
- Skip: `POST /api/v1/task_occurrences/:id/skip` with optional `skip_reason`

After each action, update the local view by invalidating task and calendar queries. For projected occurrences with `id = null`, show them as planned future work without action buttons.

## Tags
The `Tags` route should show active tags from `/api/v1/tags`.

Administrators and staff can use the same tag API surface unless backend authorization is later tightened. The UI should make system tags visibly immutable:
- `is_system_tag = true` disables edit and delete controls.
- inactive tags are hidden by default.
- admins may opt into `include_deactivated=true` for maintenance views.

Task detail should support attach and detach flows using the nested task-tag endpoints.

Full attached-tag display depends on the backend serializing task tags in task show/list responses or adding a task-tags listing endpoint. Without that contract, the frontend can list available tags and submit attach/detach actions, but it cannot reliably reconstruct existing task-tag state after a page load.

## Backend Contract Dependencies
The frontend can implement the primary task workflows with the current API, but a polished production UI depends on these backend contracts:
- a users list/search endpoint for assignee and delegation pickers
- attached tag data in task payloads, or a task-tag listing endpoint
- stable seeded users or fixtures for local manual verification

These are not blockers for the first frontend upgrade if the UI uses numeric user ids and treats attached-tag display as conditional.

## Admin Layer
The admin route should include:
- API health status from `/up`
- link to `/api-docs`
- all-task workspace presets without staff-only scopes
- tag maintenance with deactivated tags included
- role-aware labels that make global visibility obvious

Do not add user management in this frontend upgrade. The backend currently exposes current-user auth data but no users list, create, update, or delete API.

## Frontend Structure
Split the current single `App.jsx` into focused modules:
- `src/api/client.js` - fetch wrapper, auth header, error normalization.
- `src/auth/` - login page, session provider, protected route helpers.
- `src/layout/` - shell, navigation, role-aware route list.
- `src/tasks/` - list, filters, detail, form, delegation actions.
- `src/recurrence/` - recurrence mode form helpers.
- `src/tags/` - tag list, tag form, task tag picker.
- `src/calendar/` - date-window occurrence view.
- `src/admin/` - health/docs/admin presets.

React Query should remain the data-fetching and cache invalidation layer.

## Error Handling
Handle API failures consistently:
- 400: show bad request text near the relevant filter or form.
- 401: clear session and redirect to login.
- 403: show forbidden state.
- 404: show not-found state.
- 422: show validation messages from the `errors` array.
- network failure: show a retryable connection error.

Date and time inputs should submit ISO 8601 values because the backend validates those formats.

## Non-Goals
- Do not add backend endpoints in this frontend spec.
- Do not add user CRUD or user search until the backend exposes it.
- Do not implement real-time updates.
- Do not replace React Query.
- Do not redesign the backend authorization model.
- Do not expose unsupported task update fields.

## Acceptance Criteria
- A user can log in, refresh the app, and keep a valid session.
- A 401 response clears the session and returns the user to login.
- Doctors and nurses can use task filters without seeing admin-only navigation.
- Administrators can access the admin area and global task presets.
- The task list supports `scope`, `status`, `from`, `to`, and `occurrence_status`.
- Delegated pending tasks can be accepted or declined from the UI.
- One-time tasks can be created.
- Recurring tasks can be created for the required recurrence modes.
- Persisted occurrences can be postponed, executed, and skipped.
- Projected occurrences are displayed but do not show action buttons.
- Tags can be listed and submitted through attach/detach task-tag actions.
- Existing attached tags are displayed when the backend provides task-tag state.
- System tags visibly disable edit and delete controls.
- API validation errors are shown without losing form state.

## Verification Plan
- Add component or integration tests for auth state, protected routing, task filters, delegated actions, recurrence form mode switching, tag immutability, and occurrence action availability.
- Use mocked API responses for frontend tests unless a full-stack browser test is added later.
- Run the frontend test suite and linter once available.
- Manually verify the app against the local Rails API using an administrator and a staff user fixture.
