require "rails_helper"

RSpec.describe "Api::V1::Tags", type: :request do
  before do
    host! "localhost"
  end

  it "requires bearer authentication" do
    get "/api/v1/tags"

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to include("error" => "Unauthorized")
  end

  it "lists active tags by default, includes deactivated tags when requested, and deactivates tags without deleting them" do
    user = create_user(email: "doctor@example.test", role: :doctor)
    active_tag = Tag.create!(name: "Active tag", description: "Visible")
    inactive_tag = Tag.create!(name: "Inactive tag", description: "Hidden")

    delete "/api/v1/tags/#{inactive_tag.id}", headers: auth_headers_for(user)

    expect(response).to have_http_status(:no_content)
    expect(Tag.find(inactive_tag.id).deactivated_at).to be_present

    get "/api/v1/tags", headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    names = JSON.parse(response.body).dig("data").map { |item| item.dig("attributes", "name") }
    expect(names).to include("Active tag")
    expect(names).not_to include("Inactive tag")

    get "/api/v1/tags", params: { include_deactivated: true }, headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    names = JSON.parse(response.body).dig("data").map { |item| item.dig("attributes", "name") }
    expect(names).to include("Active tag", "Inactive tag")
  end

  it "creates updates and rejects direct mutation of system tags" do
    user = create_user(email: "doctor@example.test", role: :doctor)

    post "/api/v1/tags",
         params: { tag: { name: "New tag", description: "Created through the API" } },
         headers: auth_headers_for(user)

    expect(response).to have_http_status(:created)
    tag_id = JSON.parse(response.body).dig("data", "id")

    patch "/api/v1/tags/#{tag_id}",
          params: { tag: { name: "Updated tag", description: "Updated description" } },
          headers: auth_headers_for(user)

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("data", "attributes", "name")).to eq("Updated tag")

    system_tag = Tag.create!(name: "Отчётность", is_system_tag: true)

    patch "/api/v1/tags/#{system_tag.id}",
          params: { tag: { name: "Blocked" } },
          headers: auth_headers_for(user)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch("errors")).to include("system tags cannot be renamed, deactivated, or deleted")

    delete "/api/v1/tags/#{system_tag.id}", headers: auth_headers_for(user)

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).fetch("errors")).to include("system tags cannot be renamed, deactivated, or deleted")
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
