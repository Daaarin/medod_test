# == Schema Information
#
# Table name: users
#
#  id                :bigint           not null, primary key
#  auth_token_digest :string
#  email             :string           not null
#  last_name         :string           not null
#  name              :string           not null
#  password_digest   :string           not null
#  password_salt     :string           not null
#  role              :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_users_on_auth_token_digest   (auth_token_digest) UNIQUE
#  index_users_on_email               (email) UNIQUE
#  index_users_on_name_and_last_name  (name,last_name)
#
require "rails_helper"

RSpec.describe User, type: :model do
  it "requires staff identity fields" do
    user = described_class.new(
      email: "doctor@example.test",
      password: "password123",
      role: :doctor,
      name: "Ivan",
      last_name: "Petrov"
    )

    expect(user).to be_valid
    expect(described_class.roles.keys).to match_array(%w[administrator doctor nurse])
  end

  it "normalizes email addresses and rejects duplicate emails" do
    user = described_class.create!(
      email: "Doctor@Example.Test",
      password: "password123",
      role: :doctor,
      name: "Ivan",
      last_name: "Petrov"
    )

    duplicate = described_class.new(
      email: "doctor@example.test",
      password: "password123",
      role: :nurse,
      name: "Anna",
      last_name: "Sidorova"
    )

    expect(user.email).to eq("doctor@example.test")
    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:email]).to include("has already been taken")
  end

  it "stores password and token digests instead of plaintext" do
    user = described_class.create!(
      email: "doctor@example.test",
      password: "password123",
      role: :doctor,
      name: "Ivan",
      last_name: "Petrov"
    )

    expect(user.authenticate("password123")).to eq(user)
    expect(user.authenticate("wrong-password")).to be(false)
    expect(user.password_digest).not_to eq("password123")
    expect(user.password_digest).to match(/\A\h{64}\z/)

    token = user.issue_auth_token!

    expect(token).to be_present
    expect(user.auth_token_digest).not_to eq(token)
    expect(user.auth_token_digest).to match(/\A\h{64}\z/)
  end

  it "prevents destroying a user who owns tasks" do
    user = described_class.create!(
      email: "doctor@example.test",
      password: "password123",
      role: :doctor,
      name: "Ivan",
      last_name: "Petrov"
    )
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Check email",
      responsible: user
    )

    expect { user.destroy! }.to raise_error(ActiveRecord::DeleteRestrictionError)
    expect(task.reload.responsible).to eq(user)
  end
end
