require "rails_helper"

RSpec.describe "Api::V1::Tasks", type: :request do
  it "requires bearer authentication" do
    get "/api/v1/tasks"

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to include("error" => "Unauthorized")
  end

  it "creates tasks with default values, supports scoped listing, updates, shows, and deactivates them" do
    user = create_user(email: "doctor@example.test", role: :doctor)
    headers = auth_headers_for(user)

    post "/api/v1/tasks",
         params: {
           task: {
             name: "Morning rounds",
             description: "Check assigned patients",
             completion_date: "2026-05-15",
             assign_to_self: true,
             first_run_at: "2026-05-15T09:30:00+03:00",
             next_run_at: "2026-05-16T09:30:00+03:00"
           }
         },
         headers: headers

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    task_id = body.dig("data", "id")

    expect(body.dig("data", "attributes", "name")).to eq("Morning rounds")
    expect(body.dig("data", "attributes", "status")).to eq("draft")
    expect(body.dig("data", "attributes", "task_kind")).to eq("one_time")
    expect(body.dig("data", "attributes", "creator_id")).to eq(user.id)
    expect(body.dig("data", "attributes", "responsible_id")).to eq(user.id)

    get "/api/v1/tasks/#{task_id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("data", "id")).to eq(task_id)

    patch "/api/v1/tasks/#{task_id}",
          params: {
            task: {
              description: "Check assigned patients and notes",
              status: "ongoing",
              responsible_id: create_user(email: "other@example.test", role: :doctor).id,
              delegated_user_id: create_user(email: "delegate@example.test", role: :nurse).id
            }
          },
          headers: headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("data", "attributes", "description")).to eq("Check assigned patients and notes")
    expect(JSON.parse(response.body).dig("data", "attributes", "status")).to eq("draft")
    expect(JSON.parse(response.body).dig("data", "attributes", "responsible_id")).to eq(user.id)
    expect(JSON.parse(response.body).dig("data", "attributes", "delegated_user_id")).to be_nil

    get "/api/v1/tasks",
        params: {
          scope: "mine",
          from: "2026-05-14",
          to: "2026-05-16"
        },
        headers: headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("data", 0, "attributes", "name")).to eq("Morning rounds")

    delete "/api/v1/tasks/#{task_id}", headers: headers

    expect(response).to have_http_status(:no_content)
    expect(Task.find(task_id).deactivated_at).to be_present

    get "/api/v1/tasks", headers: headers

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("data").map { |item| item.dig("id") }).not_to include(task_id)
  end

  it "rejects recurring tasks without an initial schedule or recurrence rule" do
    user = create_user(email: "doctor-recurring-validation@example.test", role: :doctor)

    post "/api/v1/tasks",
         params: {
           task: {
             name: "Recurring orphan",
             task_kind: "recurring"
           }
         },
         headers: auth_headers_for(user)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch("errors")).to include(
      "recurring tasks require recurrence_rule_attributes or next_run_at"
    )
    expect(Task.find_by(name: "Recurring orphan")).to be_nil
  end

  it "rejects recurring tasks that only provide first_run_at without a recurrence rule" do
    user = create_user(email: "doctor-recurring-first-run@example.test", role: :doctor)

    post "/api/v1/tasks",
         params: {
           task: {
             name: "Recurring first run only",
             task_kind: "recurring",
             first_run_at: "2026-05-15T09:30:00+03:00"
           }
         },
         headers: auth_headers_for(user)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch("errors")).to include(
      "recurring tasks require recurrence_rule_attributes or next_run_at"
    )
    expect(Task.find_by(name: "Recurring first run only")).to be_nil
  end

  it "enforces bonded visibility for staff and broader access for administrators" do
    admin = create_user(email: "admin@example.test", role: :administrator)
    doctor = create_user(email: "doctor@example.test", role: :doctor)
    nurse = create_user(email: "nurse@example.test", role: :nurse)

    create_task(name: "Admin task", creator: admin, responsible: admin, status: :ongoing)
    create_task(name: "Doctor task", creator: doctor, responsible: doctor, status: :ongoing)
    create_task(name: "Nurse task", creator: nurse, responsible: nurse, status: :ongoing, completion_date: Date.new(2026, 5, 15))
    create_task(
      name: "Delegated task",
      creator: admin,
      delegated_user: doctor,
      status: :pending_acceptance,
      task_kind: :one_time,
      first_run_at: Time.zone.parse("2026-05-15 08:00"),
      next_run_at: Time.zone.parse("2026-05-16 08:00")
    )

    get "/api/v1/tasks", headers: auth_headers_for(admin)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("data").size).to eq(4)

    get "/api/v1/tasks", headers: auth_headers_for(doctor)

    expect(response).to have_http_status(:ok)
    doctor_names = JSON.parse(response.body).dig("data").map { |item| item.dig("attributes", "name") }
    expect(doctor_names).to match_array([ "Doctor task", "Delegated task" ])

    get "/api/v1/tasks",
        params: { scope: "created_by_me" },
        headers: auth_headers_for(doctor)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("data").map { |item| item.dig("attributes", "name") }).to match_array([ "Doctor task" ])

    get "/api/v1/tasks",
        params: { scope: "delegated_to_me" },
        headers: auth_headers_for(doctor)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("data").map { |item| item.dig("attributes", "name") }).to match_array([ "Delegated task" ])

    get "/api/v1/tasks",
        params: {
          from: "2026-05-15",
          to: "2026-05-15"
        },
        headers: auth_headers_for(admin)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("data").map { |item| item.dig("attributes", "name") }).to include("Nurse task")
    expect(JSON.parse(response.body).dig("data").map { |item| item.dig("attributes", "name") }).not_to include("Delegated task")
    expect(JSON.parse(response.body).dig("data").map { |item| item.dig("attributes", "name") }).not_to include("Admin task")

    unbonded_task_id = Task.find_by!(name: "Admin task").id

    get "/api/v1/tasks/#{unbonded_task_id}", headers: auth_headers_for(doctor)

    expect(response).to have_http_status(:not_found)
  end

  it "does not allow delegated users to mutate or deactivate before acceptance" do
    creator = create_user(email: "creator@example.test", role: :doctor)
    delegate = create_user(email: "delegate@example.test", role: :nurse)
    task = create_task(name: "Delegated task", creator: creator, delegated_user: delegate, status: :pending_acceptance)

    patch "/api/v1/tasks/#{task.id}",
          params: {
            task: {
              name: "Hijacked",
              status: "ongoing",
              responsible_id: delegate.id,
              delegated_user_id: nil
            }
          },
          headers: auth_headers_for(delegate)

    expect(response).to have_http_status(:forbidden)
    expect(task.reload.name).to eq("Delegated task")
    expect(task.status).to eq("pending_acceptance")
    expect(task.responsible_id).to be_nil
    expect(task.delegated_user_id).to eq(delegate.id)

    delete "/api/v1/tasks/#{task.id}", headers: auth_headers_for(delegate)

    expect(response).to have_http_status(:forbidden)
    expect(task.reload.deactivated_at).to be_nil
  end

  it "filters visible tasks by lifecycle status" do
    user = create_user(email: "doctor-status-filter@example.test", role: :doctor)
    create_task(name: "Draft task", creator: user, responsible: user, status: :draft)
    create_task(name: "Ongoing task", creator: user, responsible: user, status: :ongoing)
    create_task(name: "Pending task", creator: user, delegated_user: user, status: :pending_acceptance)
    cancelled_task = create_task(name: "Cancelled task", creator: user, responsible: user, status: :ongoing)
    cancelled_task.update_columns(
      status: "cancelled",
      end_reason: "manual_cancelled",
      cancelled_at: Time.current
    )

    get "/api/v1/tasks",
        params: { status: "ongoing" },
        headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    names = JSON.parse(response.body).fetch("data").map { |item| item.dig("attributes", "name") }
    expect(names).to eq([ "Ongoing task" ])
  end

  it "composes lifecycle status filtering with delegated_to_me scope" do
    creator = create_user(email: "creator-status-scope@example.test", role: :doctor)
    delegate = create_user(email: "delegate-status-scope@example.test", role: :nurse)
    create_task(name: "Pending delegated task", creator: creator, delegated_user: delegate, status: :pending_acceptance)
    create_task(name: "Own pending task", creator: delegate, responsible: delegate, status: :pending_acceptance)
    create_task(name: "Own ongoing task", creator: delegate, responsible: delegate, status: :ongoing)

    get "/api/v1/tasks",
        params: { scope: "delegated_to_me", status: "pending_acceptance" },
        headers: auth_headers_for(delegate)

    expect(response).to have_http_status(:ok)
    names = JSON.parse(response.body).fetch("data").map { |item| item.dig("attributes", "name") }
    expect(names).to eq([ "Pending delegated task" ])
  end

  it "rejects unknown lifecycle status filters" do
    user = create_user(email: "doctor-invalid-status-filter@example.test", role: :doctor)

    get "/api/v1/tasks",
        params: { status: "not_a_status" },
        headers: auth_headers_for(user)

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)).to include("error" => "status is not included in the list")
  end

  it "returns stable client errors and ignores unsafe create assignment params" do
    user = create_user(email: "doctor@example.test", role: :doctor)
    headers = auth_headers_for(user)

    get "/api/v1/tasks", params: { from: "not-a-date" }, headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)).to include("error" => "from must be an ISO 8601 date")

    post "/api/v1/tasks",
         params: {
           task: {
             name: "Invalid assignee",
             responsible_id: 999_999
           }
         },
         headers: headers

    expect(response).to have_http_status(:created)
    invalid_assignee_task = Task.find(JSON.parse(response.body).dig("data", "id"))
    expect(invalid_assignee_task.status).to eq("draft")
    expect(invalid_assignee_task.responsible_id).to be_nil
    expect(invalid_assignee_task.delegated_user_id).to be_nil

    post "/api/v1/tasks",
         params: {
           task: {
             name: "Unsafe state",
             status: "pending_acceptance",
             responsible_id: user.id,
             delegated_user_id: create_user(email: "delegate2@example.test", role: :nurse).id,
             completion_date: "not-a-date"
           }
         },
         headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)).to include("error" => "completion_date must be ISO 8601")

    delegate = create_user(email: "delegate3@example.test", role: :nurse)
    post "/api/v1/tasks",
         params: {
           task: {
             name: "Unsafe state",
             status: "ongoing",
              responsible_id: create_user(email: "other2@example.test", role: :doctor).id,
              delegated_user_id: delegate.id
           }
         },
         headers: headers

    expect(response).to have_http_status(:created)
    created_task = Task.find(JSON.parse(response.body).dig("data", "id"))
    expect(created_task.status).to eq("pending_acceptance")
    expect(created_task.responsible_id).to be_nil
    expect(created_task.delegated_user_id).to eq(delegate.id)

    patch "/api/v1/tasks/#{created_task.id}",
          params: {
            task: {
              completion_date: "also-not-a-date"
            }
          },
          headers: headers

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)).to include("error" => "completion_date must be ISO 8601")

    final_task = create_task(
      name: "Final task",
      creator: user,
      status: :ongoing
    )
    final_task.update_columns(status: "completed", end_reason: "series_completed", completed_at: Time.current)

    delete "/api/v1/tasks/#{final_task.id}", headers: headers

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch("errors")).to include("Final tasks cannot be deactivated")
    expect(final_task.reload.deactivated_at).to be_nil
  end

  it "creates delegated recurring tasks through the public API" do
    creator = create_user(email: "creator-public-recurring@example.test", role: :doctor)
    delegate = create_user(email: "delegate-public-recurring@example.test", role: :nurse)

    post "/api/v1/tasks",
         params: {
           task: {
             name: "Daily wound check",
             task_kind: "recurring",
             delegated_user_id: delegate.id,
             recurrence_rule_attributes: {
               rule_type: "every_n_days",
               interval_value: 1,
               execution_time: "10:00",
               timezone: "Europe/Moscow",
               date_start: "2026-05-15"
             }
           }
         },
         headers: auth_headers_for(creator)

    expect(response).to have_http_status(:created)
    task = Task.find(JSON.parse(response.body).dig("data", "id"))
    expect(task.status).to eq("pending_acceptance")
    expect(task.delegated_user_id).to eq(delegate.id)
    expect(task.responsible_id).to be_nil
    expect(task.recurrence_rule.rule_type).to eq("every_n_days")
    expect(task.next_run_at).to eq(Time.zone.parse("2026-05-15 10:00"))
    expect(task.task_occurrences.pluck(:status, :scheduled_at)).to eq([ [ "planned", Time.zone.parse("2026-05-15 10:00") ] ])
  end

  it "projects recurring occurrences in date-filtered task lists and filters by occurrence status" do
    user = create_user(email: "doctor-projection@example.test", role: :doctor)
    task = create_task(
      name: "Projected medicine check",
      creator: user,
      responsible: user,
      status: :ongoing,
      task_kind: :recurring
    )
    task.create_recurrence_rule!(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 15),
      date_end: Date.new(2026, 5, 17)
    )
    task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-15 10:00"),
      status: :skipped,
      skip_reason: "patient unavailable"
    )

    get "/api/v1/tasks",
        params: { from: "2026-05-15", to: "2026-05-17" },
        headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    occurrences = JSON.parse(response.body).fetch("data").map { |item| item.dig("attributes", "occurrence") }
    expect(occurrences.map { |occurrence| occurrence.fetch("scheduled_at") }).to match_array(
      [
        Time.zone.parse("2026-05-15 10:00").iso8601,
        Time.zone.parse("2026-05-16 10:00").iso8601,
        Time.zone.parse("2026-05-17 10:00").iso8601
      ]
    )
    expect(occurrences.map { |occurrence| occurrence.fetch("status") }).to match_array(%w[skipped planned planned])

    get "/api/v1/tasks",
        params: { from: "2026-05-15", to: "2026-05-17", occurrence_status: "skipped" },
        headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    filtered_occurrences = JSON.parse(response.body).fetch("data").map { |item| item.dig("attributes", "occurrence") }
    expect(filtered_occurrences.size).to eq(1)
    expect(filtered_occurrences.first.fetch("status")).to eq("skipped")
  end

  it "projects one-time tasks at next_run_at only when both scheduled timestamps are present" do
    user = create_user(email: "doctor-one-time-projection@example.test", role: :doctor)
    task = create_task(
      name: "One-time projected check",
      creator: user,
      responsible: user,
      status: :ongoing,
      task_kind: :one_time,
      first_run_at: Time.zone.parse("2026-05-15 08:00"),
      next_run_at: Time.zone.parse("2026-05-16 08:00")
    )

    get "/api/v1/tasks",
        params: { from: "2026-05-15", to: "2026-05-16" },
        headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    items = JSON.parse(response.body).fetch("data")
    expect(items.size).to eq(1)
    expect(items.first.dig("attributes", "name")).to eq(task.name)
    expect(items.first.dig("attributes", "occurrence", "scheduled_at")).to eq(Time.zone.parse("2026-05-16 08:00").iso8601)
  end

  it "narrows date-filtered task listing to relevant tasks and occurrences in SQL" do
    user = create_user(email: "doctor-date-narrowing@example.test", role: :doctor)

    projected_task = create_task(
      name: "Projected follow-up",
      creator: user,
      responsible: user,
      status: :ongoing,
      task_kind: :recurring
    )
    projected_task.create_recurrence_rule!(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 15),
      date_end: Date.new(2026, 5, 17)
    )

    occurrence_task = create_task(
      name: "Persisted occurrence window",
      creator: user,
      responsible: user,
      status: :ongoing,
      task_kind: :recurring
    )
    occurrence_task.create_recurrence_rule!(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "09:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 10),
      date_end: Date.new(2026, 5, 30)
    )
    occurrence_task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-15 09:00"),
      status: :planned,
      generated_at: Time.current
    )
    occurrence_task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-04-15 09:00"),
      status: :executed,
      actual_at: Time.zone.parse("2026-04-15 09:30"),
      generated_at: Time.current
    )

    completion_task = create_task(
      name: "Completion fallback",
      creator: user,
      responsible: user,
      status: :ongoing,
      task_kind: :one_time,
      completion_date: Date.new(2026, 5, 16)
    )

    create_task(
      name: "Historical noise",
      creator: user,
      responsible: user,
      status: :ongoing,
      task_kind: :one_time,
      completion_date: Date.new(2026, 5, 1)
    )

    create_task(
      name: "Future noise",
      creator: user,
      responsible: user,
      status: :ongoing,
      task_kind: :one_time,
      next_run_at: Time.zone.parse("2026-05-25 09:00")
    )

    instantiations = Hash.new(0)
    subscriber = ActiveSupport::Notifications.subscribe("instantiation.active_record") do |*args|
      payload = args.last
      instantiations[payload[:class_name]] += payload[:record_count]
    end

    get "/api/v1/tasks",
        params: { from: "2026-05-15", to: "2026-05-17" },
        headers: auth_headers_for(user)

    ActiveSupport::Notifications.unsubscribe(subscriber)

    expect(response).to have_http_status(:ok)
    names = JSON.parse(response.body).fetch("data").map { |item| item.dig("attributes", "name") }
    expect(names).to match_array(
      [
        "Projected follow-up",
        "Projected follow-up",
        "Projected follow-up",
        "Persisted occurrence window",
        "Persisted occurrence window",
        "Persisted occurrence window",
        "Completion fallback"
      ]
    )
    expect(instantiations["Task"]).to eq(3)
    expect(instantiations["TaskOccurrence"]).to eq(2)
  end

  it "includes active attached tags in task payloads" do
    user = create_user(email: "doctor-task-tags@example.test", role: :doctor)
    task = create_task(name: "Tagged task", creator: user, responsible: user, status: :ongoing)
    active_tag = Tag.create!(name: "Active tag")
    inactive_tag = Tag.create!(name: "Inactive tag")
    unattached_tag = Tag.create!(name: "Unattached tag")

    TaskTag.attach!(task: task, tag: active_tag)
    TaskTag.attach!(task: task, tag: inactive_tag)
    inactive_tag.deactivate!

    get "/api/v1/tasks/#{task.id}", headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    tags = JSON.parse(response.body).dig("data", "attributes", "tags")
    expect(tags.map { |tag| tag.dig("id") }).to eq([ active_tag.id.to_s ])
    expect(tags.map { |tag| tag.dig("id") }).not_to include(inactive_tag.id.to_s, unattached_tag.id.to_s)
  end

  it "composes lifecycle status and occurrence status filters for projected recurring occurrences" do
    user = create_user(email: "doctor-status-projection@example.test", role: :doctor)
    ongoing_task = create_task(
      name: "Ongoing projected check",
      creator: user,
      responsible: user,
      status: :ongoing,
      task_kind: :recurring
    )
    draft_task = create_task(
      name: "Draft projected check",
      creator: user,
      responsible: user,
      status: :draft,
      task_kind: :recurring
    )

    [ ongoing_task, draft_task ].each do |task|
      task.create_recurrence_rule!(
        rule_type: :every_n_days,
        interval_value: 1,
        execution_time: "10:00",
        timezone: "Europe/Moscow",
        date_start: Date.new(2026, 5, 15),
        date_end: Date.new(2026, 5, 17)
      )
    end

    get "/api/v1/tasks",
        params: { from: "2026-05-15", to: "2026-05-17", status: "ongoing", occurrence_status: "planned" },
        headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    items = JSON.parse(response.body).fetch("data")
    expect(items.map { |item| item.dig("attributes", "name") }).to match_array(
      [ "Ongoing projected check", "Ongoing projected check", "Ongoing projected check" ]
    )
    expect(items.map { |item| item.dig("attributes", "occurrence", "status") }).to all(eq("planned"))
  end

  def auth_headers_for(user)
    { "Authorization" => "Bearer #{user.issue_auth_token!}" }
  end

  def create_user(email:, role:)
    User.create!(
      email: email,
      password: "password123",
      role: role,
      name: email.split("@").first.capitalize,
      last_name: "User"
    )
  end

  def create_task(name:, creator:, responsible: nil, delegated_user: nil, status:, task_kind: :one_time, completion_date: nil, first_run_at: nil, next_run_at: nil)
    Task.create!(
      name: name,
      task_kind: task_kind,
      status: status,
      creator: creator,
      responsible: responsible,
      delegated_user: delegated_user,
      completion_date: completion_date,
      first_run_at: first_run_at,
      next_run_at: next_run_at
    )
  end
end
