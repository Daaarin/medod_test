require "rails_helper"

RSpec.describe TaskEvent, type: :model do
  it "exposes append-only event history and persists payload data" do
    expect(described_class.event_types.keys).to include("created", "split")

    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    event = described_class.create!(
      task: task,
      event_type: :created,
      actor_id: responsible.id,
      occurred_at: Time.zone.parse("2026-05-10 09:00"),
      payload_json: { name: "Check email" }
    )

    expect(event.payload_json["name"]).to eq("Check email")
    expect(event.update(payload_json: { name: "Updated" })).to be(false)
    expect(event.errors[:base]).to include("task events are append-only")
  end

  def build_user(email:, role:)
    User.create!(
      email:,
      password: "password123",
      role:,
      name: "Test",
      last_name: "User"
    )
  end
end
