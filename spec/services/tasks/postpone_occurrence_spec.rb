require "rails_helper"

RSpec.describe Tasks::PostponeOccurrence do
  it "marks one planned occurrence postponed and updates the task next_run_at" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible,
      next_run_at: Time.zone.parse("2026-05-11 10:00")
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-11 10:00"),
      status: :planned
    )

    described_class.call(
      occurrence: occurrence,
      postpone_to: Time.zone.parse("2026-05-12 14:00"),
      actor_id: responsible.id
    )

    expect(occurrence.reload.status).to eq("postponed")
    expect(occurrence.postponed_to).to eq(Time.zone.parse("2026-05-12 14:00"))
    expect(task.reload.next_run_at).to eq(Time.zone.parse("2026-05-12 14:00"))
    expect(task.task_events.order(:id).pluck(:event_type)).to eq([ "postponed" ])
    expect(task.task_events.order(:id).last.payload_json).to include(
      "scheduled_at" => Time.zone.parse("2026-05-11 10:00").as_json,
      "previous_next_run_at" => Time.zone.parse("2026-05-11 10:00").as_json,
      "postponed_to" => Time.zone.parse("2026-05-12 14:00").as_json
    )
  end

  it "rejects backward postponement targets before mutating" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible,
      next_run_at: Time.zone.parse("2026-05-11 10:00")
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-11 10:00"),
      status: :planned
    )

    expect do
      described_class.call(
        occurrence: occurrence,
        postpone_to: Time.zone.parse("2026-05-10 10:00"),
        actor_id: responsible.id
      )
    end.to raise_error(ArgumentError, "postpone_to must be on or after the scheduled occurrence")

    expect(occurrence.reload.status).to eq("planned")
    expect(task.reload.next_run_at).to eq(Time.zone.parse("2026-05-11 10:00"))
    expect(task.task_events).to be_empty
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
      described_class.call(
        occurrence: occurrence,
        postpone_to: Time.zone.parse("2026-05-12 14:00"),
        actor_id: responsible.id
      )
    end.to raise_error(ArgumentError, "occurrence must be planned on an active task")

    expect(occurrence.reload.status).to eq("executed")
    expect(task.reload.next_run_at).to be_nil
    expect(task.task_events).to be_empty
  end

  it "rejects final tasks before mutating" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :cancelled,
      end_reason: :manual_cancelled,
      name: "Check email",
      responsible: responsible
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-11 10:00"),
      status: :planned
    )

    expect do
      described_class.call(
        occurrence: occurrence,
        postpone_to: Time.zone.parse("2026-05-12 14:00"),
        actor_id: responsible.id
      )
    end.to raise_error(ArgumentError, "occurrence must be planned on an active task")

    expect(occurrence.reload.status).to eq("planned")
    expect(task.reload.next_run_at).to be_nil
  end

  it "rejects deactivated tasks before mutating" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible,
      deactivated_at: Time.current,
      next_run_at: Time.zone.parse("2026-05-11 10:00")
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-11 10:00"),
      status: :planned
    )

    expect do
      described_class.call(
        occurrence: occurrence,
        postpone_to: Time.zone.parse("2026-05-12 14:00"),
        actor_id: responsible.id
      )
    end.to raise_error(ArgumentError, "occurrence must be planned on an active task")

    expect(occurrence.reload.status).to eq("planned")
    expect(task.reload.next_run_at).to eq(Time.zone.parse("2026-05-11 10:00"))
    expect(task.task_events).to be_empty
  end

  it "rolls back all mutations when audit appending fails" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible,
      next_run_at: Time.zone.parse("2026-05-11 10:00")
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-11 10:00"),
      status: :planned
    )

    allow(Tasks::AppendEvent).to receive(:call).and_raise(StandardError, "boom")

    expect do
      described_class.call(
        occurrence: occurrence,
        postpone_to: Time.zone.parse("2026-05-12 14:00"),
        actor_id: responsible.id
      )
    end.to raise_error(StandardError, "boom")

    expect(occurrence.reload.status).to eq("planned")
    expect(occurrence.postponed_to).to be_nil
    expect(task.reload.next_run_at).to eq(Time.zone.parse("2026-05-11 10:00"))
    expect(task.task_events).to be_empty
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
