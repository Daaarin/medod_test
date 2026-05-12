require "rails_helper"

RSpec.describe Tasks::PostponeOccurrence do
  it "marks one planned occurrence postponed and updates the task next_run_at" do
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
    expect(task.task_events.order(:id).pluck(:event_type)).to eq([ "postponed" ])
    expect(task.task_events.order(:id).last.payload_json).to include(
      "scheduled_at" => Time.zone.parse("2026-05-11 10:00").as_json,
      "previous_next_run_at" => Time.zone.parse("2026-05-11 10:00").as_json,
      "postponed_to" => Time.zone.parse("2026-05-12 14:00").as_json
    )
  end

  it "rejects backward postponement targets before mutating" do
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

    expect do
      described_class.call(
        occurrence: occurrence,
        postpone_to: Time.zone.parse("2026-05-10 10:00"),
        actor_id: 42
      )
    end.to raise_error(ArgumentError, "postpone_to must be on or after the scheduled occurrence")

    expect(occurrence.reload.status).to eq("planned")
    expect(task.reload.next_run_at).to eq(Time.zone.parse("2026-05-11 10:00"))
    expect(task.task_events).to be_empty
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
      described_class.call(
        occurrence: occurrence,
        postpone_to: Time.zone.parse("2026-05-12 14:00"),
        actor_id: 42
      )
    end.to raise_error(ArgumentError, "occurrence must be planned on an active task")

    expect(occurrence.reload.status).to eq("executed")
    expect(task.reload.next_run_at).to be_nil
    expect(task.task_events).to be_empty
  end

  it "rejects final tasks before mutating" do
    task = Task.create!(
      task_kind: :recurring,
      status: :cancelled,
      end_reason: :manual_cancelled,
      title: "Check email",
      responsible_id: 42
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-11 10:00"),
      status: :planned
    )

    expect do
      described_class.call(
        occurrence: occurrence,
        postpone_to: Time.zone.parse("2026-05-12 14:00"),
        actor_id: 42
      )
    end.to raise_error(ArgumentError, "occurrence must be planned on an active task")

    expect(occurrence.reload.status).to eq("planned")
    expect(task.reload.next_run_at).to be_nil
  end

  it "rolls back all mutations when audit appending fails" do
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

    allow(Tasks::AppendEvent).to receive(:call).and_raise(StandardError, "boom")

    expect do
      described_class.call(
        occurrence: occurrence,
        postpone_to: Time.zone.parse("2026-05-12 14:00"),
        actor_id: 42
      )
    end.to raise_error(StandardError, "boom")

    expect(occurrence.reload.status).to eq("planned")
    expect(occurrence.postponed_to).to be_nil
    expect(task.reload.next_run_at).to eq(Time.zone.parse("2026-05-11 10:00"))
    expect(task.task_events).to be_empty
  end
end
