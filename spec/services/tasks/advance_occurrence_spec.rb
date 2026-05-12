require "rails_helper"

RSpec.describe Tasks::AdvanceOccurrence do
  include ActiveSupport::Testing::TimeHelpers

  it "executes a recurring occurrence, appends the execution event, and creates the next planned occurrence" do
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    task.create_recurrence_rule!(
      rule_type: :every_n_days,
      interval_value: 2,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-11 10:00"),
      status: :planned
    )

    travel_to(Time.zone.parse("2026-05-11 10:01")) do
      described_class.call(occurrence: occurrence, actor_id: 42)
    end

    expect(occurrence.reload.status).to eq("executed")
    expect(occurrence.actual_at).to be_present
    expect(task.reload.status).to eq("ongoing")
    expect(task.next_run_at).to eq(Time.zone.parse("2026-05-13 10:00"))
    expect(task.task_occurrences.where(status: :planned).count).to eq(1)
    expect(task.task_occurrences.where(status: :planned).pluck(:scheduled_at)).to eq([ Time.zone.parse("2026-05-13 10:00") ])
    expect(task.task_events.pluck(:event_type)).to include("executed")
  end

  it "completes a recurring lineage when there is no next scheduled run" do
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    task.create_recurrence_rule!(
      rule_type: :every_n_days,
      interval_value: 2,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1),
      date_end: Date.new(2026, 5, 5)
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-05 10:00"),
      status: :planned
    )

    travel_to(Time.zone.parse("2026-05-05 10:01")) do
      described_class.call(occurrence: occurrence, actor_id: 42)
    end

    expect(occurrence.reload.status).to eq("executed")
    expect(task.reload.status).to eq("completed")
    expect(task.end_reason).to eq("series_completed")
    expect(task.next_run_at).to be_nil
    expect(task.task_occurrences.where(status: :planned)).to be_empty
    expect(task.task_events.pluck(:event_type)).to include("completed")
  end

  it "completes a one-time lineage after its single execution" do
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42,
      next_run_at: Time.zone.parse("2026-05-12 10:00")
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :planned
    )

    travel_to(Time.zone.parse("2026-05-12 10:01")) do
      described_class.call(occurrence: occurrence, actor_id: 42)
    end

    expect(occurrence.reload.status).to eq("executed")
    expect(task.reload.status).to eq("completed")
    expect(task.end_reason).to eq("series_completed")
    expect(task.next_run_at).to be_nil
    expect(task.task_occurrences.where(status: :planned)).to be_empty
    expect(task.task_events.pluck(:event_type)).to include("completed")
  end

  it "rejects non-planned occurrences before mutating" do
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-11 10:00"),
      status: :executed
    )

    expect do
      described_class.call(occurrence: occurrence, actor_id: 42)
    end.to raise_error(ArgumentError, "occurrence must be planned on an active task")

    expect(occurrence.reload.status).to eq("executed")
    expect(task.reload.status).to eq("ongoing")
    expect(task.task_events).to be_empty
  end

  it "rejects final tasks before mutating" do
    task = Task.create!(
      task_kind: :one_time,
      status: :cancelled,
      end_reason: :manual_cancelled,
      title: "Check email",
      responsible_id: 42,
      next_run_at: Time.zone.parse("2026-05-12 10:00")
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :planned
    )

    expect do
      described_class.call(occurrence: occurrence, actor_id: 42)
    end.to raise_error(ArgumentError, "occurrence must be planned on an active task")

    expect(occurrence.reload.status).to eq("planned")
    expect(task.reload.status).to eq("cancelled")
    expect(task.task_events).to be_empty
  end
end
