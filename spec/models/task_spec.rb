require "rails_helper"

RSpec.describe Task, type: :model do
  it "exposes the expected lifecycle enums and tracks final state" do
    task = described_class.new(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )

    expect(task).to be_valid
    expect(task.task_kind).to eq("recurring")
    expect(task.status).to eq("ongoing")
    expect(task.final?).to be(false)
    expect(described_class.task_kinds.keys).to match_array(%w[one_time recurring])
    expect(described_class.statuses.keys).to match_array(%w[draft pending_acceptance ongoing completed cancelled])
    expect(described_class.end_reasons.keys).to match_array(%w[series_completed manual_cancelled responsible_changed schedule_changed])
  end

  it "requires end_reason for a final task" do
    task = described_class.new(
      task_kind: :recurring,
      status: :cancelled,
      title: "Check email",
      responsible_id: 42
    )

    expect(task).not_to be_valid
    expect(task.errors[:end_reason]).to include("must be present for final tasks")
  end

  it "is immutable once final" do
    task = described_class.create!(
      task_kind: :one_time,
      status: :cancelled,
      end_reason: :manual_cancelled,
      title: "Check email",
      responsible_id: 42
    )

    expect(task.update(title: "Updated title")).to be(false)
    expect(task.errors[:base]).to include("final tasks are immutable")
  end

  it "allows active tasks to transition into final states through the model API" do
    completed_task = described_class.create!(
      task_kind: :one_time,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    completed_at = Time.zone.parse("2026-05-12 10:00")

    expect do
      completed_task.update!(
        status: :completed,
        end_reason: :series_completed,
        completed_at: completed_at,
        next_run_at: nil
      )
    end.to change { completed_task.reload.status }.from("ongoing").to("completed")
    expect(completed_task.completed_at).to eq(completed_at)

    cancelled_task = described_class.create!(
      task_kind: :one_time,
      status: :ongoing,
      title: "Send email",
      responsible_id: 42
    )

    expect { cancelled_task.retire!(end_reason: :manual_cancelled) }
      .to change { cancelled_task.reload.status }.from("ongoing").to("cancelled")
    expect(cancelled_task.end_reason).to eq("manual_cancelled")
  end

  it "forbids recurrence rules on one-time tasks" do
    task = described_class.new(
      task_kind: :one_time,
      status: :ongoing,
      title: "Send email",
      responsible_id: 42
    )
    task.build_recurrence_rule(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 12)
    )

    expect(task).not_to be_valid
    expect(task.errors[:recurrence_rule]).to include("must be absent for one-time tasks")
  end
end
