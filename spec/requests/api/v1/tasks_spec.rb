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
    expect(JSON.parse(response.body).dig("data").map { |item| item.dig("attributes", "name") }).to include("Nurse task", "Delegated task")
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

    post "/api/v1/tasks",
         params: {
           task: {
             name: "Unsafe state",
             status: "ongoing",
             responsible_id: create_user(email: "other2@example.test", role: :doctor).id,
             delegated_user_id: create_user(email: "delegate3@example.test", role: :nurse).id
           }
         },
         headers: headers

    expect(response).to have_http_status(:created)
    created_task = Task.find(JSON.parse(response.body).dig("data", "id"))
    expect(created_task.status).to eq("draft")
    expect(created_task.responsible_id).to be_nil
    expect(created_task.delegated_user_id).to be_nil

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
