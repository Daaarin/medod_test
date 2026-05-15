require "rails_helper"

RSpec.describe "Api::V1::TaskOccurrences", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  before do
    host! "localhost"
  end

  it "requires bearer authentication" do
    user = create_user(email: "doctor-auth@example.test", role: :doctor)
    occurrence = create_recurring_task(
      name: "Daily call",
      responsible: user,
      scheduled_at: Time.zone.parse("2026-05-15 10:00")
    ).task_occurrences.first

    post "/api/v1/task_occurrences/#{occurrence.id}/postpone",
         params: { postponed_to: "2026-05-15T12:00:00+03:00" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to include("error" => "Unauthorized")
  end

  it "postpones a single occurrence and returns the updated occurrence and task payload" do
    user = create_user(email: "doctor@example.test", role: :doctor)
    task = create_recurring_task(
      name: "Daily call",
      responsible: user,
      scheduled_at: Time.zone.parse("2026-05-15 10:00")
    )
    occurrence = task.task_occurrences.first

    expect do
      post "/api/v1/task_occurrences/#{occurrence.id}/postpone",
           params: { postponed_to: "2026-05-15T12:00:00+03:00" },
           headers: auth_headers_for(user)
    end.to change(TaskEvent, :count).by(1)

    expect(response).to have_http_status(:ok)

    json = JSON.parse(response.body)
    expected_postponed_to = Time.zone.parse("2026-05-15 12:00").iso8601
    expect(json.dig("data", "occurrence", "attributes", "status")).to eq("postponed")
    expect(json.dig("data", "occurrence", "attributes", "postponed_to")).to eq(expected_postponed_to)
    expect(json.dig("data", "task", "attributes", "next_run_at")).to eq(expected_postponed_to)

    occurrence.reload
    expect(occurrence.status).to eq("postponed")
    expect(occurrence.postponed_to).to eq(Time.zone.parse("2026-05-15 12:00:00+03:00"))
    expect(task.reload.next_run_at).to eq(Time.zone.parse("2026-05-15 12:00:00+03:00"))
  end

  it "returns bad request when postponed_to is missing or invalid" do
    user = create_user(email: "doctor-invalid@example.test", role: :doctor)
    task = create_recurring_task(
      name: "Daily call",
      responsible: user,
      scheduled_at: Time.zone.parse("2026-05-15 10:00")
    )
    occurrence = task.task_occurrences.first

    post "/api/v1/task_occurrences/#{occurrence.id}/postpone", headers: auth_headers_for(user)

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)).to include("error" => "postponed_to must be ISO 8601")

    post "/api/v1/task_occurrences/#{occurrence.id}/postpone",
         params: { postponed_to: "not-an-iso-timestamp" },
         headers: auth_headers_for(user)

    expect(response).to have_http_status(:bad_request)
    expect(JSON.parse(response.body)).to include("error" => "postponed_to must be ISO 8601")
  end

  it "forbids delegated-only pending users from mutating occurrences before acceptance" do
    creator = create_user(email: "creator@example.test", role: :doctor)
    delegate = create_user(email: "delegate@example.test", role: :nurse)
    task = Task.create!(
      task_kind: :recurring,
      status: :pending_acceptance,
      name: "Pending call",
      creator: creator,
      delegated_user: delegate
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-15 10:00"),
      status: :planned
    )

    post "/api/v1/task_occurrences/#{occurrence.id}/postpone",
         params: { postponed_to: "2026-05-15T12:00:00+03:00" },
         headers: auth_headers_for(delegate)

    expect(response).to have_http_status(:forbidden)
    expect(occurrence.reload.status).to eq("planned")

    post "/api/v1/task_occurrences/#{occurrence.id}/execute", headers: auth_headers_for(delegate)

    expect(response).to have_http_status(:forbidden)
    expect(occurrence.reload.status).to eq("planned")

    post "/api/v1/task_occurrences/#{occurrence.id}/skip", headers: auth_headers_for(delegate)

    expect(response).to have_http_status(:forbidden)
    expect(occurrence.reload.status).to eq("planned")
  end

  it "returns not found for outsiders who cannot see the task" do
    responsible = create_user(email: "responsible@example.test", role: :doctor)
    outsider = create_user(email: "outsider@example.test", role: :nurse)
    task = create_recurring_task(
      name: "Visible call",
      responsible: responsible,
      scheduled_at: Time.zone.parse("2026-05-15 10:00")
    )
    occurrence = task.task_occurrences.first

    post "/api/v1/task_occurrences/#{occurrence.id}/execute", headers: auth_headers_for(outsider)

    expect(response).to have_http_status(:not_found)
  end

  it "rejects backward postponement as a domain error" do
    user = create_user(email: "doctor-backward@example.test", role: :doctor)
    task = create_recurring_task(
      name: "Daily call",
      responsible: user,
      scheduled_at: Time.zone.parse("2026-05-15 10:00")
    )
    occurrence = task.task_occurrences.first

    post "/api/v1/task_occurrences/#{occurrence.id}/postpone",
         params: { postponed_to: "2026-05-15T08:00:00+03:00" },
         headers: auth_headers_for(user)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch("errors")).to include("postpone_to must be on or after the scheduled occurrence")
    expect(occurrence.reload.status).to eq("planned")
    expect(task.reload.next_run_at).to eq(Time.zone.parse("2026-05-15 10:00"))
  end

  it "rejects non-current occurrences and non-active tasks with domain errors" do
    user = create_user(email: "doctor-domain@example.test", role: :doctor)
    task = create_recurring_task(
      name: "Daily call",
      responsible: user,
      scheduled_at: Time.zone.parse("2026-05-15 10:00")
    )
    current_occurrence = task.task_occurrences.find_by!(status: :planned)
    executed_occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-14 10:00"),
      status: :executed,
      actual_at: Time.zone.parse("2026-05-14 10:01")
    )

    post "/api/v1/task_occurrences/#{executed_occurrence.id}/execute", headers: auth_headers_for(user)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch("errors")).to include("occurrence must be planned or postponed on an active task")
    expect(current_occurrence.reload.status).to eq("planned")
    expect(executed_occurrence.reload.status).to eq("executed")

    cancelled_task = Task.create!(
      task_kind: :recurring,
      status: :cancelled,
      end_reason: :manual_cancelled,
      name: "Cancelled call",
      responsible: user
    )
    cancelled_occurrence = cancelled_task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-15 10:00"),
      status: :planned
    )

    post "/api/v1/task_occurrences/#{cancelled_occurrence.id}/skip", headers: auth_headers_for(user)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch("errors")).to include("occurrence must be planned or postponed on an active task")
    expect(cancelled_occurrence.reload.status).to eq("planned")
  end

  it "executes a current occurrence, advances the task, and leaves siblings untouched" do
    user = create_user(email: "doctor-execute@example.test", role: :doctor)
    task = create_recurring_task(
      name: "Daily call",
      responsible: user,
      scheduled_at: Time.zone.parse("2026-05-15 10:00")
    )
    sibling = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-14 10:00"),
      status: :executed,
      actual_at: Time.zone.parse("2026-05-14 10:01")
    )
    current_occurrence = task.task_occurrences.find_by!(status: :planned)

    travel_to(Time.zone.parse("2026-05-15 10:01")) do
      expect do
        post "/api/v1/task_occurrences/#{current_occurrence.id}/execute",
             headers: auth_headers_for(user)
      end.to change(TaskEvent, :count).by(1)
    end

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expected_next_run_at = Time.zone.parse("2026-05-16 10:00").iso8601
    expect(json.dig("data", "occurrence", "attributes", "status")).to eq("executed")
    expect(json.dig("data", "task", "attributes", "next_run_at")).to eq(expected_next_run_at)

    task.reload
    expect(task.status).to eq("ongoing")
    expect(task.next_run_at).to eq(Time.zone.parse("2026-05-16 10:00"))
    expect(task.task_occurrences.order(:scheduled_at).pluck(:status)).to eq(%w[executed executed planned])
    expect(task.task_occurrences.find(sibling.id).status).to eq("executed")
  end

  it "skips a current occurrence without mutating siblings and keeps the series moving" do
    user = create_user(email: "doctor-skip@example.test", role: :doctor)
    task = create_recurring_task(
      name: "Daily call",
      responsible: user,
      scheduled_at: Time.zone.parse("2026-05-15 10:00")
    )
    sibling = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-14 10:00"),
      status: :executed,
      actual_at: Time.zone.parse("2026-05-14 10:01")
    )
    current_occurrence = task.task_occurrences.find_by!(status: :planned)

    travel_to(Time.zone.parse("2026-05-15 10:01")) do
      expect do
        post "/api/v1/task_occurrences/#{current_occurrence.id}/skip",
             headers: auth_headers_for(user)
      end.to change(TaskEvent, :count).by(1)
    end

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expected_next_run_at = Time.zone.parse("2026-05-16 10:00").iso8601
    expect(json.dig("data", "occurrence", "attributes", "status")).to eq("skipped")
    expect(json.dig("data", "occurrence", "attributes", "skip_reason")).to eq("skipped")
    expect(json.dig("data", "task", "attributes", "next_run_at")).to eq(expected_next_run_at)

    task.reload
    expect(task.next_run_at).to eq(Time.zone.parse("2026-05-16 10:00"))
    expect(task.task_occurrences.order(:scheduled_at).pluck(:status)).to eq(%w[executed skipped planned])
    expect(task.task_occurrences.find(sibling.id).status).to eq("executed")
    expect(task.task_events.order(:id).last.event_type).to eq("skipped")
  end

  it "skips a one-time occurrence and finalizes the task" do
    user = create_user(email: "doctor-skip-one-time@example.test", role: :doctor)
    scheduled_at = Time.zone.parse("2026-05-15 10:00")
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "One-time call",
      responsible: user,
      next_run_at: scheduled_at
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: scheduled_at,
      status: :planned
    )

    travel_to(Time.zone.parse("2026-05-15 10:01")) do
      expect do
        post "/api/v1/task_occurrences/#{occurrence.id}/skip",
             params: { skip_reason: "patient unavailable" },
             headers: auth_headers_for(user)
      end.to change(TaskEvent, :count).by(2)
    end

    expect(response).to have_http_status(:ok)
    expect(occurrence.reload.status).to eq("skipped")
    expect(occurrence.skip_reason).to eq("patient unavailable")
    expect(task.reload.status).to eq("completed")
    expect(task.end_reason).to eq("series_completed")
    expect(task.next_run_at).to be_nil
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

  def create_recurring_task(name:, responsible:, scheduled_at:, creator: nil, delegated_user: nil, status: :ongoing)
    task = Task.create!(
      task_kind: :recurring,
      status: status,
      name: name,
      creator: creator,
      responsible: responsible,
      delegated_user: delegated_user,
      next_run_at: scheduled_at
    )

    task.create_recurrence_rule!(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: scheduled_at.strftime("%H:%M"),
      timezone: "Europe/Moscow",
      date_start: scheduled_at.to_date
    )

    task.task_occurrences.create!(
      scheduled_at: scheduled_at,
      status: :planned
    )

    task
  end
end
