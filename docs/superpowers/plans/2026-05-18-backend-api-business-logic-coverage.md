# Backend/API: план полного покрытия бизнес-логики

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Довести backend/API-часть репозитория до 100% line + branch coverage по бизнес-логике без изменения публичного HTTP-поведения.

**Architecture:** Покрытие добивается через локально изолированный coverage-runner, адресное закрытие пробелов в model/service/presenter/request-спеках и один небольшой внутренний seam для сериализации occurrence payload. Публичные маршруты, параметры, статусы и JSON-контракты API не меняются.

**Tech Stack:** Rails 8, RSpec, SimpleCov, rswag, PostgreSQL.

---

## Краткое резюме

- Scope ограничен `backend + API`: `app/controllers/api/v1`, `app/controllers/application_controller.rb`, `app/models`, `app/services`, `app/presenters`.
- `frontend/`, `db/`, `config/`, `spec/`, `swagger/`, `vendor/` в coverage-цель не входят.
- Enforcement только локальный: нужен строгий coverage-runner с порогом `100% lines` и `100% branches`, но без CI-gate.
- Разрешен только малый внутренний refactor-seam ради тестируемости; бизнес-логика и внешний API должны остаться без изменений.

## Ключевые изменения

### 1. Coverage wiring

- Добавить `simplecov` в test stack и включать его только в отдельном strict coverage entrypoint, чтобы обычный `bundle exec rspec` оставался быстрым и без обязательного coverage-режима.
- Настроить фильтрацию coverage по backend/API scope:
  - include: `app/controllers/api/v1/**/*.rb`, `app/controllers/application_controller.rb`, `app/models/**/*.rb`, `app/services/**/*.rb`, `app/presenters/**/*.rb`
  - exclude: `frontend/**`, `db/**`, `config/**`, `spec/**`, `swagger/**`, `vendor/**`
- Зафиксировать локальный порог `minimum_coverage line: 100` и `minimum_coverage branch: 100`.
- Добавить отдельную локальную команду запуска strict coverage и кратко описать ее в `README.md`.

### 2. Малый internal seam для устойчивого покрытия

- Не менять публичный API: маршруты, request params, response payload shape, HTTP status codes, swagger contract.
- Вынести сборку occurrence JSON в отдельный API-level helper/presenter, который покрывает:
  - persisted occurrence payload;
  - projected occurrence payload;
  - `occurs_at`, `projected`, `skip_reason`, `postponed_to`, `generated_at`.
- Оставить `Api::V1::TaskPayloadPresenter` владельцем task payload, а occurrence payload собирать через новый выделенный объект.
- Не делать более широкий рефакторинг `TasksController`, если coverage gap можно закрыть тестами.

### 3. Закрытие пробелов по backend-подсистемам

- **Presenter coverage**
  - Добавить прямой spec для `Api::V1::TaskPayloadPresenter`.
  - Покрыть ветки:
    - `creator` / `responsible` / `delegated_user` как `nil` и как заполненные сущности;
    - отсутствие `recurrence_rule`;
    - наличие `recurrence_rule` c `effective_recurrence_end_date`;
    - фильтрацию деактивированных `task_tags` и деактивированных `tags`;
    - сортировку tags по `created_at`, `id`;
    - `completion_date`, `first_run_at`, `next_run_at`, `accepted_at`, `completed_at`, `cancelled_at`, `deactivated_at`.
- **Occurrence presenter coverage**
  - Добавить unit spec для нового occurrence presenter/helper.
  - Покрыть persisted ветки `planned`, `postponed`, `executed`, `skipped`.
  - Покрыть projected planned occurrence без `id` и без `generated_at`.
- **Service coverage**
  - Добавить отдельный `spec/services/tasks/skip_occurrence_spec.rb`.
  - Покрыть:
    - skip recurring occurrence с созданием следующего planned occurrence;
    - skip one-time occurrence с финализацией task;
    - skip последнего recurring occurrence с финализацией task;
    - дефолтный `skip_reason = "skipped"`;
    - кастомный `skip_reason`;
    - ошибка для не-current occurrence;
    - ошибка для неактивной task.
- **Model coverage**
  - Расширить `spec/models/task_occurrence_spec.rb`.
  - Добавить прямые тесты на:
    - `current?` для `planned`, `postponed`, `executed`, `skipped`, `cancelled`, `superseded`;
    - `actionable_time` с `postponed_to` и без него.
- **Request/API coverage**
  - Доработать `spec/requests/api/v1/tasks_spec.rb` по coverage report, а не по предположениям.
  - Закрыть неохваченные ветки для:
    - `scope`: `mine`, `delegated_to_me`, `created_by_me`, default;
    - `status` и `occurrence_status`: валидные и невалидные значения;
    - `from`-only, `to`-only, invalid ISO date;
    - `include_unscheduled=true/false`;
    - projected planned occurrences без persisted occurrence;
    - recurring task без `recurrence_rule`, но с `next_run_at`;
    - create/update/destroy веток с assignee normalization, forbidden, final-task rejection.
  - Проверить coverage пробелы в `task_occurrences`, `task_acceptances`, `task_tags`, `tags`, `users`, `auth`; добавлять только недостающие branch tests, без дублирования уже защищенных сценариев.

## Проверка и критерии приемки

- `bundle exec rspec` остается полностью зеленым.
- Отдельная strict coverage команда проходит только при `100% lines + 100% branches` по выбранному backend/API scope.
- Любой временный refactor-seam не меняет:
  - HTTP routes;
  - query/body params;
  - response JSON shape;
  - swagger behavior.
- Если после extraction меняется API payload, это считается регрессией и исправляется кодом, а не обновлением спеки.
- После реализации обновить knowledge graph командой `graphify update .`.

## Зафиксированные решения и ограничения

- Scope: только backend + API.
- Требование “full coverage” трактуется как формальное `100% line + branch coverage`.
- Coverage gate только локальный, без обязательного CI enforcement.
- Разрешен только небольшой internal seam ради тестируемости.
- `HISTORY.md` в рамках этой задачи не обновляется по явному пользовательскому указанию.
