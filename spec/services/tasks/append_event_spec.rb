require "rails_helper"

RSpec.describe Tasks::AppendEvent do
  it "appends a single task event row with the given payload and occurrence" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    occurrence = task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :planned
    )

    event = described_class.call(
      task: task,
      event_type: :created,
      actor_id: responsible.id,
      occurrence: occurrence,
      payload: { name: "Check email" }
    )

    expect(event).to be_persisted
    expect(event.task).to eq(task)
    expect(event.occurrence).to eq(occurrence)
    expect(event.event_type).to eq("created")
    expect(event.actor_id).to eq(responsible.id)
    expect(event.payload_json).to include("name" => "Check email")
  end

  it "rejects an occurrence from another task" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    other_responsible = build_user(email: "other@example.test", role: :nurse)
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    other_task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Other task",
      responsible: other_responsible
    )
    occurrence = other_task.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :planned
    )

    expect do
      described_class.call(
        task: task,
        event_type: :created,
        actor_id: responsible.id,
        occurrence: occurrence,
        payload: { name: "Check email" }
      )
    end.to raise_error(ActiveRecord::RecordInvalid, /must belong to the same task/)

    expect(TaskEvent.count).to eq(0)
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
