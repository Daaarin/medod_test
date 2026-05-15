require "rails_helper"

RSpec.describe "Api::V1::TaskAcceptances", type: :request do
  before do
    host! "localhost"
  end

  it "requires bearer authentication" do
    task = create_task(
      name: "Review lab results",
      creator: create_user(email: "creator@example.test", role: :administrator),
      delegated_user: create_user(email: "delegate@example.test", role: :doctor),
      status: :pending_acceptance
    )

    post "/api/v1/tasks/#{task.id}/accept"

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to include("error" => "Unauthorized")
  end

  it "accepts a delegated task and appends an accepted event" do
    creator = create_user(email: "creator@example.test", role: :administrator)
    delegate = create_user(email: "delegate@example.test", role: :doctor)
    task = create_task(
      name: "Review lab results",
      creator: creator,
      delegated_user: delegate,
      status: :pending_acceptance
    )

    expect do
      post "/api/v1/tasks/#{task.id}/accept", headers: auth_headers_for(delegate)
    end.to change(TaskEvent, :count).by(1)

    expect(response).to have_http_status(:ok)

    task.reload
    expect(task.responsible).to eq(delegate)
    expect(task.delegated_user).to be_nil
    expect(task.status).to eq("ongoing")
    expect(task.accepted_at).to be_present

    event = task.task_events.order(:id).last
    expect(event.event_type).to eq("accepted")
    expect(event.actor_id).to eq(delegate.id)
    expect(event.payload_json).to include(
      "status" => "ongoing",
      "responsible_id" => delegate.id,
      "delegated_user_id" => nil
    )
  end

  it "declines a delegated task and appends a cancelled event" do
    creator = create_user(email: "creator2@example.test", role: :administrator)
    delegate = create_user(email: "delegate2@example.test", role: :doctor)
    task = create_task(
      name: "Review lab results",
      creator: creator,
      delegated_user: delegate,
      status: :pending_acceptance
    )

    expect do
      post "/api/v1/tasks/#{task.id}/decline", headers: auth_headers_for(delegate)
    end.to change(TaskEvent, :count).by(1)

    expect(response).to have_http_status(:ok)

    task.reload
    expect(task.status).to eq("cancelled")
    expect(task.end_reason).to eq("declined")
    expect(task.cancellation_reason).to eq("was declined")
    expect(task.cancelled_at).to be_present

    event = task.task_events.order(:id).last
    expect(event.event_type).to eq("cancelled")
    expect(event.actor_id).to eq(delegate.id)
    expect(event.payload_json).to include(
      "status" => "cancelled",
      "end_reason" => "declined",
      "cancellation_reason" => "was declined"
    )
  end

  it "returns forbidden for visible tasks when the caller is not the delegate" do
    creator = create_user(email: "creator3@example.test", role: :administrator)
    delegate = create_user(email: "delegate3@example.test", role: :doctor)
    task = create_task(
      name: "Review lab results",
      creator: creator,
      delegated_user: delegate,
      status: :pending_acceptance
    )

    post "/api/v1/tasks/#{task.id}/accept", headers: auth_headers_for(creator)

    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)).to include("error" => "Forbidden")

    post "/api/v1/tasks/#{task.id}/decline", headers: auth_headers_for(creator)

    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)).to include("error" => "Forbidden")
  end

  it "returns not found for tasks outside the caller's visibility" do
    creator = create_user(email: "creator4@example.test", role: :administrator)
    delegate = create_user(email: "delegate4@example.test", role: :doctor)
    outsider = create_user(email: "outsider@example.test", role: :nurse)
    task = create_task(
      name: "Review lab results",
      creator: creator,
      delegated_user: delegate,
      status: :pending_acceptance
    )

    post "/api/v1/tasks/#{task.id}/accept", headers: auth_headers_for(outsider)

    expect(response).to have_http_status(:not_found)
  end

  it "rejects acceptance and decline when the task is no longer pending acceptance" do
    creator = create_user(email: "creator5@example.test", role: :administrator)
    delegate = create_user(email: "delegate5@example.test", role: :doctor)
    accepted_task = create_task(
      name: "Already accepted",
      creator: creator,
      delegated_user: delegate,
      status: :pending_acceptance
    )
    accepted_task.update_columns(
      status: "ongoing",
      accepted_at: Time.current,
      responsible_id: delegate.id
    )

    post "/api/v1/tasks/#{accepted_task.id}/accept", headers: auth_headers_for(delegate)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch("errors")).not_to be_empty

    cancelled_task = create_task(
      name: "Already cancelled",
      creator: creator,
      delegated_user: delegate,
      status: :pending_acceptance
    )
    cancelled_task.update_columns(
      status: "cancelled",
      end_reason: "declined",
      cancellation_reason: "was declined",
      cancelled_at: Time.current
    )

    post "/api/v1/tasks/#{cancelled_task.id}/decline", headers: auth_headers_for(delegate)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch("errors")).not_to be_empty
  end

  it "does not append duplicate events on repeated acceptance attempts" do
    creator = create_user(email: "creator6@example.test", role: :administrator)
    delegate = create_user(email: "delegate6@example.test", role: :doctor)
    task = create_task(
      name: "Double submit",
      creator: creator,
      delegated_user: delegate,
      status: :pending_acceptance
    )

    expect do
      post "/api/v1/tasks/#{task.id}/accept", headers: auth_headers_for(delegate)
    end.to change(TaskEvent, :count).by(1)

    expect do
      post "/api/v1/tasks/#{task.id}/accept", headers: auth_headers_for(delegate)
    end.not_to change(TaskEvent, :count)

    expect(response).to have_http_status(:forbidden)
    expect(task.reload.status).to eq("ongoing")
  end

  it "rechecks deactivation under the acceptance lock before appending events" do
    creator = create_user(email: "creator7@example.test", role: :administrator)
    delegate = create_user(email: "delegate7@example.test", role: :doctor)
    task = create_task(
      name: "Stale visibility",
      creator: creator,
      delegated_user: delegate,
      status: :pending_acceptance
    )

    allow_any_instance_of(Task).to receive(:with_lock).and_wrap_original do |original, *args, &block|
      task.update_column(:deactivated_at, Time.current)
      original.call(*args, &block)
    end

    expect do
      post "/api/v1/tasks/#{task.id}/accept", headers: auth_headers_for(delegate)
    end.not_to change(TaskEvent, :count)

    expect(response).to have_http_status(:not_found)
    expect(task.reload.status).to eq("pending_acceptance")
    expect(task.responsible_id).to be_nil
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

  def create_task(name:, creator:, delegated_user:, status:, responsible: nil)
    Task.create!(
      name: name,
      task_kind: :one_time,
      status: status,
      creator: creator,
      responsible: responsible,
      delegated_user: delegated_user
    )
  end
end
