require "rails_helper"

RSpec.describe Tasks::SplitLineage do
  include ActiveSupport::Testing::TimeHelpers

  it "retires the parent, appends split history, and clones the planned occurrence to the child on responsible changes" do
    parent = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      description: "Daily review",
      responsible_id: 42,
      first_run_at: Time.zone.parse("2026-05-11 10:00"),
      next_run_at: Time.zone.parse("2026-05-12 10:00")
    )
    parent.create_recurrence_rule!(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )
    planned_occurrence = parent.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :planned
    )

    child = described_class.call(
      task: parent,
      end_reason: :responsible_changed,
      responsible_id: 77,
      actor_id: 99
    )

    child_occurrence = child.task_occurrences.first

    expect(parent.reload).to be_final
    expect(parent.status).to eq("cancelled")
    expect(parent.end_reason).to eq("responsible_changed")
    expect(parent.cancelled_at).to be_present
    expect(parent.next_run_at).to be_nil
    expect(parent.task_occurrences.pluck(:id, :status)).to eq([ [ planned_occurrence.id, "superseded" ] ])
    expect(parent.task_events.order(:id).pluck(:event_type)).to eq([ "split" ])
    expect(parent.task_events.order(:id).last.payload_json).to include(
      "child_task_id" => child.id,
      "source_current_occurrence_id" => planned_occurrence.id,
      "source_current_occurrence_status" => "planned",
      "child_occurrence_id" => child_occurrence.id,
      "child_next_run_at" => child.next_run_at.as_json
    )

    expect(child.parent_task).to eq(parent)
    expect(child.root_task).to eq(parent)
    expect(child.responsible_id).to eq(77)
    expect(child.status).to eq("ongoing")
    expect(child.description).to eq("Daily review")
    expect(child.next_run_at).to eq(Time.zone.parse("2026-05-12 10:00"))
    expect(child.recurrence_rule).to be_present
    expect(child.recurrence_rule.rule_type).to eq("every_n_days")
    expect(child.recurrence_rule.interval_value).to eq(1)
    expect(child_occurrence.id).not_to eq(planned_occurrence.id)
    expect(child_occurrence.task).to eq(child)
    expect(child_occurrence.status).to eq("planned")
    expect(child.task_occurrences.where(status: :planned).count).to eq(1)
    expect(child.task_events.order(:id).pluck(:event_type)).to eq([ "created" ])
    expect(child.task_events.order(:id).last.payload_json).to include(
      "parent_task_id" => parent.id,
      "responsible_id" => 77,
      "source_current_occurrence_id" => planned_occurrence.id,
      "source_current_occurrence_status" => "planned",
      "child_occurrence_id" => child_occurrence.id,
      "child_next_run_at" => child.next_run_at.as_json
    )
  end

  it "supersedes the parent occurrence and creates a new child occurrence for schedule changes" do
    travel_to(Time.zone.parse("2026-05-12 09:00")) do
      parent = Task.create!(
        task_kind: :recurring,
        status: :ongoing,
        title: "Check email",
        responsible_id: 42,
        first_run_at: Time.zone.parse("2026-05-11 10:00"),
        next_run_at: Time.zone.parse("2026-05-12 10:00")
      )
      parent.create_recurrence_rule!(
        rule_type: :every_n_days,
        interval_value: 1,
        execution_time: "10:00",
        timezone: "Europe/Moscow",
        date_start: Date.new(2026, 5, 1)
      )
      planned_occurrence = parent.task_occurrences.create!(
        scheduled_at: Time.zone.parse("2026-05-12 10:00"),
        status: :planned
      )

      child = described_class.call(
        task: parent,
        end_reason: :schedule_changed,
        recurrence_rule_attributes: {
          rule_type: :every_n_days,
          interval_value: 1,
          execution_time: "14:00",
          timezone: "Europe/Moscow",
          date_start: Date.new(2026, 5, 12)
        },
        actor_id: 88
      )

      child_occurrence = child.task_occurrences.first

      expect(parent.reload).to be_final
      expect(parent.end_reason).to eq("schedule_changed")
      expect(parent.task_occurrences.pluck(:id, :status)).to eq([ [ planned_occurrence.id, "superseded" ] ])
      expect(parent.task_occurrences.first.reload.scheduled_at).to eq(Time.zone.parse("2026-05-12 10:00"))
      expect(parent.task_events.order(:id).pluck(:event_type)).to eq([ "split" ])
      expect(parent.task_events.order(:id).last.payload_json).to include(
        "child_task_id" => child.id,
        "source_current_occurrence_id" => planned_occurrence.id,
        "source_current_occurrence_status" => "planned",
        "child_occurrence_id" => child_occurrence.id,
        "child_occurrence_status" => "planned",
        "child_next_run_at" => child.next_run_at.as_json
      )

      expect(child.parent_task).to eq(parent)
      expect(child.root_task).to eq(parent)
      expect(child.responsible_id).to eq(42)
      expect(child.recurrence_rule.execution_time.strftime("%H:%M")).to eq("14:00")
      expect(child_occurrence.task).to eq(child)
      expect(child_occurrence.status).to eq("planned")
      expect(child.task_occurrences.where(status: :planned).pluck(:scheduled_at)).to eq([ Time.zone.parse("2026-05-12 14:00") ])
      expect(child.next_run_at).to eq(Time.zone.parse("2026-05-12 14:00"))
      expect(child.task_events.order(:id).pluck(:event_type)).to eq([ "created" ])
    end
  end

  it "supersedes a postponed current occurrence and creates a new child occurrence on schedule changes" do
    travel_to(Time.zone.parse("2026-05-12 09:00")) do
      parent = Task.create!(
        task_kind: :recurring,
        status: :ongoing,
        title: "Check email",
        responsible_id: 42,
        first_run_at: Time.zone.parse("2026-05-11 10:00"),
        next_run_at: Time.zone.parse("2026-05-11 10:00")
      )
      parent.create_recurrence_rule!(
        rule_type: :every_n_days,
        interval_value: 1,
        execution_time: "10:00",
        timezone: "Europe/Moscow",
        date_start: Date.new(2026, 5, 1)
      )
      planned_occurrence = parent.task_occurrences.create!(
        scheduled_at: Time.zone.parse("2026-05-11 10:00"),
        status: :planned
      )

      Tasks::PostponeOccurrence.call(
        occurrence: planned_occurrence,
        postpone_to: Time.zone.parse("2026-05-12 14:00"),
        actor_id: 42
      )

      child = described_class.call(
        task: parent,
        end_reason: :schedule_changed,
        recurrence_rule_attributes: {
          rule_type: :every_n_days,
          interval_value: 1,
          execution_time: "14:00",
          timezone: "Europe/Moscow",
          date_start: Date.new(2026, 5, 12)
        },
        actor_id: 88
      )

      child_occurrence = child.task_occurrences.first

      expect(parent.reload).to be_final
      expect(parent.task_occurrences.pluck(:id, :status)).to eq([ [ planned_occurrence.id, "superseded" ] ])
      expect(parent.task_events.order(:id).pluck(:event_type)).to eq([ "postponed", "split" ])

      expect(child.parent_task).to eq(parent)
      expect(child_occurrence.status).to eq("planned")
      expect(child_occurrence.scheduled_at).to eq(Time.zone.parse("2026-05-12 14:00"))
      expect(child.next_run_at).to eq(Time.zone.parse("2026-05-12 14:00"))
      expect(child.recurrence_rule.execution_time.strftime("%H:%M")).to eq("14:00")
      expect(child.task_events.order(:id).pluck(:event_type)).to eq([ "created" ])
    end
  end

  it "clears the child next_run_at when the replacement schedule has no future occurrence" do
    travel_to(Time.zone.parse("2026-05-12 23:00")) do
      parent = Task.create!(
        task_kind: :recurring,
        status: :ongoing,
        title: "Check email",
        responsible_id: 42,
        first_run_at: Time.zone.parse("2026-05-11 10:00"),
        next_run_at: Time.zone.parse("2026-05-12 10:00")
      )
      parent.create_recurrence_rule!(
        rule_type: :every_n_days,
        interval_value: 1,
        execution_time: "10:00",
        timezone: "Europe/Moscow",
        date_start: Date.new(2026, 5, 1)
      )
      parent.task_occurrences.create!(
        scheduled_at: Time.zone.parse("2026-05-12 10:00"),
        status: :planned
      )

      child = described_class.call(
        task: parent,
        end_reason: :schedule_changed,
        recurrence_rule_attributes: {
          rule_type: :every_n_days,
          interval_value: 1,
          execution_time: "14:00",
          timezone: "Europe/Moscow",
          date_start: Date.new(2026, 5, 12),
          date_end: Date.new(2026, 5, 12)
        },
        actor_id: 88
      )

      expect(parent.reload).to be_final
      expect(parent.task_occurrences.pluck(:id, :status)).to eq([ [ parent.task_occurrences.first.id, "superseded" ] ])
      expect(child.next_run_at).to be_nil
      expect(child.task_occurrences).to be_empty
      expect(child.task_events.order(:id).pluck(:event_type)).to eq([ "created" ])
    end
  end

  it "rolls back all mutations when audit appending fails" do
    parent = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42,
      next_run_at: Time.zone.parse("2026-05-12 10:00")
    )
    parent.create_recurrence_rule!(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )
    parent.task_occurrences.create!(
      scheduled_at: Time.zone.parse("2026-05-12 10:00"),
      status: :planned
    )

    allow(Tasks::AppendEvent).to receive(:call).and_raise(StandardError, "boom")

    expect do
      described_class.call(
        task: parent,
        end_reason: :responsible_changed,
        responsible_id: 77,
        actor_id: 99
      )
    end.to raise_error(StandardError, "boom")

    expect(parent.reload.status).to eq("ongoing")
    expect(parent.end_reason).to be_nil
    expect(parent.task_occurrences.pluck(:status)).to eq([ "planned" ])
    expect(Task.where(parent_task_id: parent.id)).to be_empty
    expect(parent.task_events).to be_empty
  end

  it "rejects final parents before mutating" do
    parent = Task.create!(
      task_kind: :recurring,
      status: :cancelled,
      end_reason: :manual_cancelled,
      title: "Check email",
      responsible_id: 42
    )

    expect do
      described_class.call(task: parent, end_reason: :responsible_changed, responsible_id: 77, actor_id: 99)
    end.to raise_error(ArgumentError, "task must be active")
  end

  it "rejects end reasons that do not structurally replace the task" do
    parent = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )

    expect do
      described_class.call(task: parent, end_reason: :manual_cancelled, actor_id: 99)
    end.to raise_error(ArgumentError, "end_reason must be responsible_changed or schedule_changed")

    expect(parent.reload.status).to eq("ongoing")
    expect(Task.where(parent_task_id: parent.id)).to be_empty
    expect(parent.task_events).to be_empty
  end

  it "requires a replacement responsible for responsible changes" do
    parent = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )

    expect do
      described_class.call(task: parent, end_reason: :responsible_changed, actor_id: 99)
    end.to raise_error(ArgumentError, "responsible_id is required for responsible_changed")
  end

  it "requires replacement recurrence attributes for schedule changes" do
    parent = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )

    expect do
      described_class.call(task: parent, end_reason: :schedule_changed, actor_id: 99)
    end.to raise_error(ArgumentError, "recurrence_rule_attributes are required for schedule_changed")
  end
end
