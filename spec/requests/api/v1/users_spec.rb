require "rails_helper"

RSpec.describe "Api::V1::Users", type: :request do
  it "returns selectable users for administrators" do
    admin = create_user(email: "admin-users@example.test", role: :administrator)
    doctor = create_user(email: "doctor-users@example.test", role: :doctor)
    nurse = create_user(email: "nurse-users@example.test", role: :nurse)

    get "/api/v1/users", headers: auth_headers_for(admin)

    expect(response).to have_http_status(:ok)
    payload = JSON.parse(response.body)
    display_names = payload.fetch("data").map { |item| item.dig("attributes", "display_name") }

    expect(display_names).to include(doctor.display_name, nurse.display_name)
    expect(display_names.first).to eq(admin.display_name)
  end

  it "forbids non administrators from listing users" do
    user = create_user(email: "doctor-forbidden-users@example.test", role: :doctor)

    get "/api/v1/users", headers: auth_headers_for(user)

    expect(response).to have_http_status(:forbidden)
    expect(JSON.parse(response.body)).to include("error" => "Forbidden")
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
