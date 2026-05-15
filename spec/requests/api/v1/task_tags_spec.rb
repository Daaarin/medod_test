require "rails_helper"

RSpec.describe "Api::V1::TaskTags", type: :request do
  before do
    host! "localhost"
  end

  it "requires bearer authentication" do
    creator = create_user(email: "creator-auth@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Assign label",
      creator: creator,
      responsible: creator
    )
    tag = Tag.create!(name: "Auth")

    post "/api/v1/tasks/#{task.id}/tags/#{tag.id}"

    expect(response).to have_http_status(:unauthorized)
  end

  it "attaches, detaches, and reactivates the same task tag row" do
    creator = create_user(email: "creator@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Assign label",
      creator: creator,
      responsible: creator
    )
    tag = Tag.create!(name: "Operations")

    post "/api/v1/tasks/#{task.id}/tags/#{tag.id}", headers: auth_headers_for(creator)

    expect(response).to have_http_status(:ok)
    expect(TaskTag.count).to eq(1)

    task_tag = TaskTag.find_by!(task: task, tag: tag)
    task_tag_id = task_tag.id
    expect(task_tag.deactivated_at).to be_nil

    delete "/api/v1/tasks/#{task.id}/tags/#{tag.id}", headers: auth_headers_for(creator)

    expect(response).to have_http_status(:no_content)
    expect(TaskTag.count).to eq(1)
    expect(task_tag.reload.deactivated_at).to be_present

    post "/api/v1/tasks/#{task.id}/tags/#{tag.id}", headers: auth_headers_for(creator)

    expect(response).to have_http_status(:ok)
    expect(TaskTag.count).to eq(1)
    expect(task_tag.reload.id).to eq(task_tag_id)
    expect(task_tag.deactivated_at).to be_nil
  end

  it "allows administrators and responsible users to mutate task tags" do
    creator = create_user(email: "creator-write@example.test", role: :doctor)
    responsible = create_user(email: "responsible-write@example.test", role: :nurse)
    admin = create_user(email: "admin-write@example.test", role: :administrator)
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Assign label",
      creator: creator,
      responsible: responsible
    )
    tag = Tag.create!(name: "Write")

    post "/api/v1/tasks/#{task.id}/tags/#{tag.id}", headers: auth_headers_for(responsible)

    expect(response).to have_http_status(:ok)
    expect(TaskTag.find_by!(task: task, tag: tag).deactivated_at).to be_nil

    delete "/api/v1/tasks/#{task.id}/tags/#{tag.id}", headers: auth_headers_for(admin)

    expect(response).to have_http_status(:no_content)
    expect(TaskTag.find_by!(task: task, tag: tag).deactivated_at).to be_present
  end

  it "detaches a task tag after the tag itself was deactivated" do
    creator = create_user(email: "creator-inactive@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Assign inactive label",
      creator: creator,
      responsible: creator
    )
    tag = Tag.create!(name: "Inactive")
    task_tag = TaskTag.create!(task: task, tag: tag)
    tag.update!(deactivated_at: Time.current)

    delete "/api/v1/tasks/#{task.id}/tags/#{tag.id}", headers: auth_headers_for(creator)

    expect(response).to have_http_status(:no_content)
    expect(task_tag.reload.deactivated_at).to be_present
  end

  it "forbids delegated-only users from mutating task tags before acceptance" do
    creator = create_user(email: "creator@example.test", role: :doctor)
    delegate = create_user(email: "delegate@example.test", role: :nurse)
    task = Task.create!(
      task_kind: :one_time,
      status: :pending_acceptance,
      name: "Pending assignment",
      creator: creator,
      delegated_user: delegate
    )
    tag = Tag.create!(name: "Call")

    post "/api/v1/tasks/#{task.id}/tags/#{tag.id}", headers: auth_headers_for(delegate)

    expect(response).to have_http_status(:forbidden)
    expect(TaskTag.count).to eq(0)

    delete "/api/v1/tasks/#{task.id}/tags/#{tag.id}", headers: auth_headers_for(delegate)

    expect(response).to have_http_status(:forbidden)
    expect(TaskTag.count).to eq(0)
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
end
