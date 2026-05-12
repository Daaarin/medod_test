require "rails_helper"

RSpec.describe TaskEvent, type: :model do
  it "exposes append-only event history and persists payload data" do
    expect(described_class.event_types.keys).to include("created")

    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    event = described_class.create!(
      task: task,
      event_type: :created,
      actor_id: 42,
      occurred_at: Time.zone.parse("2026-05-10 09:00"),
      payload_json: { title: "Check email" }
    )

    expect(event.payload_json["title"]).to eq("Check email")
    expect(event.update(payload_json: { title: "Updated" })).to be(false)
    expect(event.errors[:base]).to include("task events are append-only")
  end
end
