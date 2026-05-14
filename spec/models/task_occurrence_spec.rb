require "rails_helper"

RSpec.describe TaskOccurrence, type: :model do
  it "exposes the planned lifecycle and allows one current future occurrence per task" do
    expect(described_class.statuses.keys).to match_array(%w[planned postponed executed skipped superseded cancelled])

    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :planned
    )

    duplicate = task.task_occurrences.new(
      scheduled_at: Time.zone.parse("2026-05-19 10:00"),
      status: :planned
    )

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:task_id]).to include("already has a current occurrence")
  end

  it "treats planned and postponed occurrences as the same current slot" do
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :postponed,
      postponed_to: Time.zone.parse("2026-05-12 14:00")
    )

    planned = task.task_occurrences.new(
      scheduled_at: Time.zone.parse("2026-05-13 10:00"),
      status: :planned
    )

    expect(planned).not_to be_valid
    expect(planned.errors[:task_id]).to include("already has a current occurrence")

    task.task_occurrences.destroy_all
    task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :planned
    )

    postponed = task.task_occurrences.new(
      scheduled_at: Time.zone.parse("2026-05-13 10:00"),
      status: :postponed,
      postponed_to: Time.zone.parse("2026-05-13 14:00")
    )

    expect(postponed).not_to be_valid
    expect(postponed.errors[:task_id]).to include("already has a current occurrence")
  end
end
