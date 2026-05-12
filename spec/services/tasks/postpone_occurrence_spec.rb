require "rails_helper"

RSpec.describe Tasks::PostponeOccurrence do
  it "marks one occurrence postponed and updates the task next_run_at" do
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42,
      next_run_at: Time.zone.parse("2026-05-11 10:00")
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-11 10:00"),
      status: :planned
    )

    described_class.call(
      occurrence: occurrence,
      postpone_to: Time.zone.parse("2026-05-12 14:00"),
      actor_id: 42
    )

    expect(occurrence.reload.status).to eq("postponed")
    expect(occurrence.postponed_to).to eq(Time.zone.parse("2026-05-12 14:00"))
    expect(task.reload.next_run_at).to eq(Time.zone.parse("2026-05-12 14:00"))
    expect(task.task_events.last.event_type).to eq("postponed")
    expect(task.task_events.last.payload_json).to include("postponed_to" => Time.zone.parse("2026-05-12 14:00"))
  end
end
