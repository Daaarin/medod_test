require "rails_helper"

RSpec.describe Tasks::AdvanceOccurrence do
  include ActiveSupport::Testing::TimeHelpers

  it "executes a recurring occurrence, appends the execution event, and creates the next planned occurrence" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
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
      described_class.call(occurrence: occurrence, actor_id: responsible.id)
    end

    expect(occurrence.reload.status).to eq("executed")
    expect(occurrence.actual_at).to be_present
    expect(task.reload.status).to eq("ongoing")
    expect(task.next_run_at).to eq(Time.zone.parse("2026-05-13 10:00"))
    expect(task.task_occurrences.where(status: :planned).count).to eq(1)
    expect(task.task_occurrences.where(status: :planned).pluck(:scheduled_at)).to eq([ Time.zone.parse("2026-05-13 10:00") ])
    expect(task.task_events.order(:id).pluck(:event_type)).to eq([ "executed" ])
  end

  it "rejects executing a planned occurrence before its scheduled time" do
    responsible = build_user(email: "responsible-future@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-11 10:00"),
      status: :planned
    )

    travel_to(Time.zone.parse("2026-05-11 09:59")) do
      expect do
        described_class.call(occurrence: occurrence, actor_id: responsible.id)
      end.to raise_error(ArgumentError, "occurrence cannot be executed before its actionable time")
    end

    expect(occurrence.reload.status).to eq("planned")
    expect(occurrence.actual_at).to be_nil
    expect(task.reload.task_occurrences.where(status: :planned).pluck(:scheduled_at)).to eq([ Time.zone.parse("2026-05-11 10:00") ])
    expect(task.task_events).to be_empty
  end

  it "completes a recurring lineage when there is no next scheduled run" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
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
      described_class.call(occurrence: occurrence, actor_id: responsible.id)
    end

    expect(occurrence.reload.status).to eq("executed")
    expect(task.reload.status).to eq("completed")
    expect(task.end_reason).to eq("series_completed")
    expect(task.next_run_at).to be_nil
    expect(task.task_occurrences.where(status: :planned)).to be_empty
    expect(task.task_events.order(:id).pluck(:event_type)).to eq([ "executed", "completed" ])
  end

  it "completes a one-time lineage after its single execution" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Check email",
      responsible: responsible,
      next_run_at: Time.zone.parse("2026-05-12 10:00")
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :planned
    )

    travel_to(Time.zone.parse("2026-05-12 10:01")) do
      described_class.call(occurrence: occurrence, actor_id: responsible.id)
    end

    expect(occurrence.reload.status).to eq("executed")
    expect(task.reload.status).to eq("completed")
    expect(task.end_reason).to eq("series_completed")
    expect(task.next_run_at).to be_nil
    expect(task.task_occurrences.where(status: :planned)).to be_empty
    expect(task.task_events.order(:id).pluck(:event_type)).to eq([ "executed", "completed" ])
  end

  it "executes a postponed occurrence and creates the next planned occurrence" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    task.create_recurrence_rule!(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-11 10:00"),
      status: :planned
    )

    Tasks::PostponeOccurrence.call(
      occurrence: occurrence,
      postpone_to: Time.zone.parse("2026-05-12 14:00"),
      actor_id: responsible.id
    )

    travel_to(Time.zone.parse("2026-05-12 14:01")) do
      described_class.call(occurrence: occurrence, actor_id: responsible.id)
    end

    expect(occurrence.reload.status).to eq("executed")
    expect(occurrence.actual_at).to be_present
    expect(task.reload.status).to eq("ongoing")
    expect(task.next_run_at).to eq(Time.zone.parse("2026-05-13 10:00"))
    expect(task.task_occurrences.where(status: :planned).pluck(:scheduled_at)).to eq([ Time.zone.parse("2026-05-13 10:00") ])
    expect(task.task_events.order(:id).pluck(:event_type)).to eq([ "postponed", "executed" ])
  end

  it "rejects executing a postponed occurrence before its postponed time" do
    responsible = build_user(email: "responsible-postponed@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    task.create_recurrence_rule!(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-11 10:00"),
      status: :planned
    )

    Tasks::PostponeOccurrence.call(
      occurrence: occurrence,
      postpone_to: Time.zone.parse("2026-05-12 14:00"),
      actor_id: responsible.id
    )

    travel_to(Time.zone.parse("2026-05-12 13:59")) do
      expect do
        described_class.call(occurrence: occurrence, actor_id: responsible.id)
      end.to raise_error(ArgumentError, "occurrence cannot be executed before its actionable time")
    end

    expect(occurrence.reload.status).to eq("postponed")
    expect(occurrence.actual_at).to be_nil
    expect(task.reload.next_run_at).to eq(Time.zone.parse("2026-05-12 14:00"))
    expect(task.task_occurrences.where(status: :planned)).to be_empty
    expect(task.task_events.order(:id).pluck(:event_type)).to eq([ "postponed" ])
  end

  it "rejects non-planned occurrences before mutating" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-11 10:00"),
      status: :executed
    )

    expect do
      described_class.call(occurrence: occurrence, actor_id: responsible.id)
    end.to raise_error(ArgumentError, "occurrence must be planned or postponed on an active task")

    expect(occurrence.reload.status).to eq("executed")
    expect(task.reload.status).to eq("ongoing")
    expect(task.task_events).to be_empty
  end

  it "rejects final tasks before mutating" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :one_time,
      status: :cancelled,
      end_reason: :manual_cancelled,
      name: "Check email",
      responsible: responsible,
      next_run_at: Time.zone.parse("2026-05-12 10:00")
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :planned
    )

    expect do
      described_class.call(occurrence: occurrence, actor_id: responsible.id)
    end.to raise_error(ArgumentError, "occurrence must be planned or postponed on an active task")

    expect(occurrence.reload.status).to eq("planned")
    expect(task.reload.status).to eq("cancelled")
    expect(task.task_events).to be_empty
  end

  it "rolls back all mutations when audit appending fails" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
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

    allow(Tasks::AppendEvent).to receive(:call).and_raise(StandardError, "boom")

    expect do
      described_class.call(occurrence: occurrence, actor_id: responsible.id)
    end.to raise_error(StandardError, "boom")

    expect(occurrence.reload.status).to eq("planned")
    expect(occurrence.actual_at).to be_nil
    expect(task.reload.status).to eq("ongoing")
    expect(task.next_run_at).to be_nil
    expect(task.task_events).to be_empty
    expect(task.task_occurrences.where(status: :planned).pluck(:scheduled_at)).to eq([ Time.zone.parse("2026-05-11 10:00") ])
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
