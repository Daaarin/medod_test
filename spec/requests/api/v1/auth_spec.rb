require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  before do
    host! "localhost"
  end

  it "throttles repeated failed login attempts from the same IP and normalized email" do
    User.create!(
      email: "doctor@example.test",
      password: "password123",
      role: :doctor,
      name: "Ivan",
      last_name: "Petrov"
    )

    headers = { "REMOTE_ADDR" => "203.0.113.10" }

    5.times do |attempt|
      post "/api/v1/auth/login",
           params: {
             email: attempt.even? ? "  DOCTOR@example.test " : "doctor@example.test",
             password: "wrong-password"
           },
           headers: headers,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    post "/api/v1/auth/login",
         params: { email: "doctor@example.test", password: "wrong-password" },
         headers: headers,
         as: :json

    expect(response).to have_http_status(:too_many_requests)
    expect(JSON.parse(response.body)).to include("error" => "Too many login attempts")
  end

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

  it "registers a new non-admin user and returns a bearer token with user data" do
    post "/api/v1/auth/register",
         params: {
           email: "register@example.test",
           password: "password123",
           role: "doctor",
           name: "Anna",
           last_name: "Sidorova"
         },
         as: :json

    expect(response).to have_http_status(:created)
    body = JSON.parse(response.body)
    expect(body["token"]).to be_present
    expect(body["user"]).to include(
      "email" => "register@example.test",
      "role" => "doctor",
      "name" => "Anna",
      "last_name" => "Sidorova"
    )
  end

  it "rejects duplicate emails during registration" do
    User.create!(
      email: "register@example.test",
      password: "password123",
      role: :doctor,
      name: "Anna",
      last_name: "Sidorova"
    )

    post "/api/v1/auth/register",
         params: {
           email: "register@example.test",
           password: "password123",
           role: "doctor",
           name: "Anna",
           last_name: "Sidorova"
         },
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["errors"]).to include("Email has already been taken")
  end

  it "rejects missing required registration fields" do
    post "/api/v1/auth/register",
         params: {
           email: "missing@example.test",
           password: "password123",
           role: "doctor"
         },
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["errors"]).to include(
      "Name can't be blank",
      "Last name can't be blank"
    )
  end

  it "rejects admin registration attempts" do
    post "/api/v1/auth/register",
         params: {
           email: "admin-register@example.test",
           password: "password123",
           role: "administrator",
           name: "Admin",
           last_name: "User"
         },
         as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    expect(JSON.parse(response.body)["errors"]).to include("Role is not allowed")
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
