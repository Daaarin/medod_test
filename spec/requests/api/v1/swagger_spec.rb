require "swagger_helper"

RSpec.describe "API V1 Swagger", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before do
    host! "localhost"
  end

  def create_user(email:, role: :doctor)
    User.create!(
      email: email,
      password: "password123",
      role: role,
      name: email.split("@").first.capitalize,
      last_name: "User"
    )
  end

  def token_for(user)
    user.issue_auth_token!
  end

  path "/api/v1/auth/login" do
    post "Authenticate and issue a bearer token" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :credentials, in: :body, schema: {
        type: :object,
        required: %w[email password],
        properties: {
          email: { type: :string },
          password: { type: :string }
        }
      }

      response "200", "authenticated" do
        let(:credentials) { { email: "swagger-login@example.test", password: "password123" } }

        before do
          create_user(email: "swagger-login@example.test")
        end

        run_test!
      end
    end
  end

  path "/api/v1/auth/register" do
    post "Register a new non-admin user" do
      tags "Auth"
      consumes "application/json"
      produces "application/json"
      parameter name: :registration, in: :body, schema: {
        type: :object,
        required: %w[email password role name last_name],
        properties: {
          email: { type: :string },
          password: { type: :string },
          role: { type: :string, enum: %w[doctor nurse] },
          name: { type: :string },
          last_name: { type: :string }
        }
      }

      response "201", "registered" do
        let(:registration) do
          {
            email: "swagger-register@example.test",
            password: "password123",
            role: "doctor",
            name: "Swagger",
            last_name: "User"
          }
        end

        run_test!
      end
    end
  end

  path "/api/v1/auth/me" do
    get "Return the current authenticated user" do
      tags "Auth"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string

      response "200", "current user" do
        let(:user) { create_user(email: "swagger-me@example.test") }
        let(:Authorization) { "Bearer #{token_for(user)}" }

        run_test!
      end
    end
  end

  path "/api/v1/tasks" do
    get "List visible tasks" do
      tags "Tasks"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string
      parameter name: :scope, in: :query, required: false, schema: { type: :string, enum: %w[mine delegated_to_me created_by_me] }
      parameter name: :from, in: :query, required: false, schema: { type: :string, format: :date }
      parameter name: :to, in: :query, required: false, schema: { type: :string, format: :date }

      response "200", "visible tasks" do
        let(:user) { create_user(email: "swagger-task-list@example.test") }
        let(:Authorization) { "Bearer #{token_for(user)}" }

        before do
          Task.create!(task_kind: :one_time, status: :ongoing, name: "Swagger task", responsible: user)
        end

        run_test!
      end
    end

    post "Create a task draft" do
      tags "Tasks"
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string
      parameter name: :task_request, in: :body, schema: {
        type: :object,
        required: [ "task" ],
        properties: {
          task: {
            type: :object,
            required: [ "name" ],
            properties: {
              name: { type: :string },
              description: { type: :string },
              completion_date: { type: :string, format: :date },
              task_kind: { type: :string, enum: %w[one_time recurring] },
              assign_to_self: { type: :boolean }
            }
          }
        }
      }

      response "201", "task created" do
        let(:user) { create_user(email: "swagger-task-create@example.test") }
        let(:Authorization) { "Bearer #{token_for(user)}" }
        let(:task_request) { { task: { name: "Swagger created task", assign_to_self: true } } }

        run_test!
      end
    end
  end

  path "/api/v1/tasks/{id}" do
    delete "Deactivate a task without deleting its row" do
      tags "Tasks"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string
      parameter name: :id, in: :path, type: :string

      response "204", "task deactivated" do
        let(:user) { create_user(email: "swagger-task-delete@example.test") }
        let(:task) { Task.create!(task_kind: :one_time, status: :ongoing, name: "Swagger delete", responsible: user) }
        let(:id) { task.id }
        let(:Authorization) { "Bearer #{token_for(user)}" }

        run_test!
      end
    end
  end

  path "/api/v1/tasks/{task_id}/accept" do
    post "Accept a delegated task" do
      tags "Tasks"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string
      parameter name: :task_id, in: :path, type: :string

      response "200", "task accepted" do
        let(:creator) { create_user(email: "swagger-accept-creator@example.test", role: :administrator) }
        let(:delegate) { create_user(email: "swagger-accept-delegate@example.test") }
        let(:task) { Task.create!(task_kind: :one_time, status: :pending_acceptance, name: "Swagger accept", creator: creator, delegated_user: delegate) }
        let(:task_id) { task.id }
        let(:Authorization) { "Bearer #{token_for(delegate)}" }

        run_test!
      end
    end
  end

  path "/api/v1/tasks/{task_id}/decline" do
    post "Decline a delegated task" do
      tags "Tasks"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string
      parameter name: :task_id, in: :path, type: :string

      response "200", "task declined" do
        let(:creator) { create_user(email: "swagger-decline-creator@example.test", role: :administrator) }
        let(:delegate) { create_user(email: "swagger-decline-delegate@example.test") }
        let(:task) { Task.create!(task_kind: :one_time, status: :pending_acceptance, name: "Swagger decline", creator: creator, delegated_user: delegate) }
        let(:task_id) { task.id }
        let(:Authorization) { "Bearer #{token_for(delegate)}" }

        run_test!
      end
    end
  end

  path "/api/v1/tags" do
    get "List active tags" do
      tags "Tags"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string

      response "200", "tags listed" do
        let(:user) { create_user(email: "swagger-tags@example.test") }
        let(:Authorization) { "Bearer #{token_for(user)}" }

        before do
          Tag.create!(name: "Swagger tag")
        end

        run_test!
      end
    end
  end

  path "/api/v1/tasks/{task_id}/tags/{tag_id}" do
    post "Attach or reactivate a tag on a task" do
      tags "Tags"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string
      parameter name: :task_id, in: :path, type: :string
      parameter name: :tag_id, in: :path, type: :string

      response "200", "tag attached" do
        let(:user) { create_user(email: "swagger-tag-attach@example.test") }
        let(:task) { Task.create!(task_kind: :one_time, status: :ongoing, name: "Swagger tag attach", responsible: user) }
        let(:tag) { Tag.create!(name: "Swagger attach") }
        let(:task_id) { task.id }
        let(:tag_id) { tag.id }
        let(:Authorization) { "Bearer #{token_for(user)}" }

        run_test!
      end
    end

    delete "Detach a tag from a task by deactivating the join row" do
      tags "Tags"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string
      parameter name: :task_id, in: :path, type: :string
      parameter name: :tag_id, in: :path, type: :string

      response "204", "tag detached" do
        let(:user) { create_user(email: "swagger-tag-detach@example.test") }
        let(:task) { Task.create!(task_kind: :one_time, status: :ongoing, name: "Swagger tag detach", responsible: user) }
        let(:tag) { Tag.create!(name: "Swagger detach") }
        let(:task_id) { task.id }
        let(:tag_id) { tag.id }
        let(:Authorization) { "Bearer #{token_for(user)}" }

        before do
          TaskTag.create!(task: task, tag: tag)
        end

        run_test!
      end
    end
  end

  path "/api/v1/task_occurrences/{id}/postpone" do
    post "Postpone one task occurrence" do
      tags "Occurrences"
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string
      parameter name: :id, in: :path, type: :string
      parameter name: :postpone_request, in: :body, schema: {
        type: :object,
        required: [ "postponed_to" ],
        properties: {
          postponed_to: { type: :string, format: "date-time" }
        }
      }

      response "200", "occurrence postponed" do
        let(:user) { create_user(email: "swagger-occurrence@example.test") }
        let(:scheduled_at) { Time.zone.parse("2026-05-15 10:00") }
        let(:task) do
          Task.create!(
            task_kind: :recurring,
            status: :ongoing,
            name: "Swagger occurrence",
            responsible: user,
            next_run_at: scheduled_at
          ).tap do |created_task|
            created_task.create_recurrence_rule!(
              rule_type: :every_n_days,
              interval_value: 1,
              execution_time: "10:00",
              timezone: "Europe/Moscow",
              date_start: Date.new(2026, 5, 15)
            )
          end
        end
        let(:occurrence) { task.task_occurrences.create!(scheduled_at: scheduled_at, status: :planned) }
        let(:id) { occurrence.id }
        let(:Authorization) { "Bearer #{token_for(user)}" }
        let(:postpone_request) { { postponed_to: "2026-05-15T12:00:00+03:00" } }

        run_test!
      end
    end
  end

  path "/api/v1/task_occurrences/{id}/execute" do
    post "Execute one task occurrence" do
      tags "Occurrences"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string
      parameter name: :id, in: :path, type: :string

      response "200", "occurrence executed" do
        let(:user) { create_user(email: "swagger-execute@example.test") }
        let(:task) do
          Task.create!(
            task_kind: :recurring,
            status: :ongoing,
            name: "Swagger execute",
            responsible: user,
            next_run_at: Time.zone.parse("2026-05-15 10:00")
          ).tap do |created_task|
            created_task.create_recurrence_rule!(
              rule_type: :every_n_days,
              interval_value: 1,
              execution_time: "10:00",
              timezone: "Europe/Moscow",
              date_start: Date.new(2026, 5, 15)
            )
          end
        end
        let(:occurrence) { task.task_occurrences.create!(scheduled_at: Time.zone.parse("2026-05-15 10:00"), status: :planned) }
        let(:id) { occurrence.id }
        let(:Authorization) { "Bearer #{token_for(user)}" }

        around do |example|
          travel_to(Time.zone.parse("2026-05-15 10:01")) do
            example.run
          end
        end

        run_test!
      end
    end
  end

  path "/api/v1/task_occurrences/{id}/skip" do
    post "Skip one task occurrence" do
      tags "Occurrences"
      consumes "application/json"
      produces "application/json"
      security [ bearerAuth: [] ]
      parameter name: :Authorization, in: :header, type: :string
      parameter name: :id, in: :path, type: :string
      parameter name: :skip_request, in: :body, schema: {
        type: :object,
        properties: {
          skip_reason: { type: :string }
        }
      }

      response "200", "occurrence skipped" do
        let(:user) { create_user(email: "swagger-skip@example.test") }
        let(:task) do
          Task.create!(
            task_kind: :recurring,
            status: :ongoing,
            name: "Swagger skip",
            responsible: user,
            next_run_at: Time.zone.parse("2026-05-15 10:00")
          ).tap do |created_task|
            created_task.create_recurrence_rule!(
              rule_type: :every_n_days,
              interval_value: 1,
              execution_time: "10:00",
              timezone: "Europe/Moscow",
              date_start: Date.new(2026, 5, 15)
            )
          end
        end
        let(:occurrence) { task.task_occurrences.create!(scheduled_at: Time.zone.parse("2026-05-15 10:00"), status: :planned) }
        let(:id) { occurrence.id }
        let(:Authorization) { "Bearer #{token_for(user)}" }
        let(:skip_request) { { skip_reason: "patient unavailable" } }

        run_test!
      end
    end
  end
end
