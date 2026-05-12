require "rails_helper"

RSpec.describe Tasks::AppendEvent do
  it "appends a single task event row with the given payload and occurrence" do
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :planned
    )

    event = described_class.call(
      task: task,
      event_type: :created,
      actor_id: 42,
      occurrence: occurrence,
      payload: { title: "Check email" }
    )

    expect(event).to be_persisted
    expect(event.task).to eq(task)
    expect(event.occurrence).to eq(occurrence)
    expect(event.event_type).to eq("created")
    expect(event.actor_id).to eq(42)
    expect(event.payload_json).to include("title" => "Check email")
  end
end
