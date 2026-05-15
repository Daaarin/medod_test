require "rails_helper"

RSpec.describe Task, type: :model do
  it "exposes the expected lifecycle enums, task associations, and tracks final state" do
    creator = build_user(email: "creator@example.test", role: :administrator)
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    delegated_user = build_user(email: "delegate@example.test", role: :nurse)

    task = described_class.new(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      creator: creator,
      responsible: responsible,
      delegated_user: delegated_user
    )

    expect(task).to be_valid
    expect(task.task_kind).to eq("recurring")
    expect(task.status).to eq("ongoing")
    expect(task.final?).to be(false)
    expect(task.creator).to eq(creator)
    expect(task.responsible).to eq(responsible)
    expect(task.delegated_user).to eq(delegated_user)
    expect(described_class.task_kinds.keys).to match_array(%w[one_time recurring])
    expect(described_class.statuses.keys).to match_array(%w[draft pending_acceptance ongoing completed cancelled])
    expect(described_class.end_reasons.keys).to match_array(%w[series_completed manual_cancelled responsible_changed schedule_changed declined])
  end

  it "requires end_reason for a final task" do
    task = described_class.new(
      task_kind: :recurring,
      status: :cancelled,
      name: "Check email",
      creator: build_user(email: "creator@example.test", role: :administrator)
    )

    expect(task).not_to be_valid
    expect(task.errors[:end_reason]).to include("must be present for final tasks")
  end

  it "allows responsible to be absent when creator or delegated user is present" do
    task = described_class.new(
      task_kind: :one_time,
      status: :draft,
      name: "Review lab results",
      creator: build_user(email: "creator@example.test", role: :administrator),
      delegated_user: build_user(email: "delegate@example.test", role: :doctor)
    )

    expect(task).to be_valid
    expect(task.responsible).to be_nil
  end

  it "treats deactivated tasks as inactive" do
    task = described_class.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Review lab results",
      responsible: build_user(email: "responsible@example.test", role: :doctor)
    )

    expect(task).to be_active

    task.update!(deactivated_at: Time.current)

    expect(task).not_to be_active
    expect(task).not_to be_final
  end

  it "rejects tasks that have no ownership context" do
    task = described_class.new(
      task_kind: :one_time,
      status: :draft,
      name: "Orphan task"
    )

    expect(task).not_to be_valid
    expect(task.errors[:base]).to include("must have a creator, responsible user, or delegated user")
  end

  it "is immutable once final" do
    task = described_class.create!(
      task_kind: :one_time,
      status: :cancelled,
      end_reason: :manual_cancelled,
      name: "Check email",
      creator: build_user(email: "creator@example.test", role: :administrator)
    )

    expect(task.update(name: "Updated name")).to be(false)
    expect(task.errors[:base]).to include("final tasks are immutable")
  end

  it "allows active tasks to transition into final states through the model API" do
    completed_task = described_class.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Check email",
      responsible: build_user(email: "responsible@example.test", role: :doctor)
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
      name: "Send email",
      delegated_user: build_user(email: "delegate@example.test", role: :nurse)
    )

    expect { cancelled_task.retire!(end_reason: :manual_cancelled) }
      .to change { cancelled_task.reload.status }.from("ongoing").to("cancelled")
    expect(cancelled_task.end_reason).to eq("manual_cancelled")
    expect(cancelled_task.cancellation_reason).to eq("manual_cancelled")
    expect(cancelled_task.cancelled_at).to be_present
  end

  it "allows retire! to accept explicit cancellation metadata" do
    task = described_class.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Check email",
      delegated_user: build_user(email: "delegate@example.test", role: :nurse)
    )
    cancelled_at = Time.zone.parse("2026-05-12 11:00")

    task.retire!(
      end_reason: :declined,
      cancelled_at: cancelled_at,
      cancellation_reason: "declined by assignee"
    )

    expect(task.reload.status).to eq("cancelled")
    expect(task.end_reason).to eq("declined")
    expect(task.cancellation_reason).to eq("declined by assignee")
    expect(task.cancelled_at).to eq(cancelled_at)
  end

  it "forbids recurrence rules on one-time tasks" do
    task = described_class.new(
      task_kind: :one_time,
      status: :ongoing,
      name: "Send email",
      responsible: build_user(email: "responsible@example.test", role: :doctor)
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
