require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  it "authenticates a user and returns a bearer token with user data" do
    User.create!(
      email: "doctor@example.test",
      password: "password123",
      role: :doctor,
      name: "Ivan",
      last_name: "Petrov"
    )

    post "/api/v1/auth/login", params: { email: "doctor@example.test", password: "password123" }

    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["token"]).to be_present
    expect(body["user"]).to include(
      "email" => "doctor@example.test",
      "role" => "doctor",
      "name" => "Ivan",
      "last_name" => "Petrov"
    )
  end

  it "rejects invalid login credentials" do
    User.create!(
      email: "doctor@example.test",
      password: "password123",
      role: :doctor,
      name: "Ivan",
      last_name: "Petrov"
    )

    post "/api/v1/auth/login", params: { email: "doctor@example.test", password: "wrong-password" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to include("error" => "Invalid email or password")
  end

  it "returns the current user for a bearer token" do
    user = User.create!(
      email: "doctor@example.test",
      password: "password123",
      role: :doctor,
      name: "Ivan",
      last_name: "Petrov"
    )

    post "/api/v1/auth/login", params: { email: user.email, password: "password123" }
    token = JSON.parse(response.body).fetch("token")

    get "/api/v1/auth/me", headers: { "Authorization" => "Bearer #{token}" }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).dig("user", "email")).to eq("doctor@example.test")
  end

  it "rejects requests without a bearer token" do
    get "/api/v1/auth/me"

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to include("error" => "Unauthorized")
  end

  it "rejects requests with an invalid bearer token" do
    get "/api/v1/auth/me", headers: { "Authorization" => "Bearer invalid-token" }

    expect(response).to have_http_status(:unauthorized)
    expect(JSON.parse(response.body)).to include("error" => "Unauthorized")
  end
end
