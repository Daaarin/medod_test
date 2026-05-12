require "rails_helper"

RSpec.describe Tasks::SplitLineage do
  include ActiveSupport::Testing::TimeHelpers

  it "retires the parent, appends split history, and transfers the planned occurrence to the child on responsible changes" do
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

    expect(parent.reload).to be_final
    expect(parent.status).to eq("cancelled")
    expect(parent.end_reason).to eq("responsible_changed")
    expect(parent.cancelled_at).to be_present
    expect(parent.next_run_at).to be_nil
    expect(parent.task_occurrences.where(status: :planned)).to be_empty
    expect(parent.task_events.pluck(:event_type)).to include("split")
    expect(parent.task_events.last.payload_json).to include(
      "child_task_id" => child.id,
      "source_planned_occurrence_id" => planned_occurrence.id
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
    expect(child.task_occurrences.where(status: :planned).count).to eq(1)
    expect(child.task_occurrences.pluck(:id)).to contain_exactly(planned_occurrence.id)
    expect(child.task_events.pluck(:event_type)).to include("created")
    expect(child.task_events.last.payload_json).to include(
      "parent_task_id" => parent.id,
      "source_planned_occurrence_id" => planned_occurrence.id
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

      expect(parent.reload).to be_final
      expect(parent.end_reason).to eq("schedule_changed")
      expect(parent.task_occurrences.pluck(:status)).to eq([ "superseded" ])
      expect(parent.task_occurrences.first.reload.scheduled_at).to eq(Time.zone.parse("2026-05-12 10:00"))
      expect(parent.task_events.pluck(:event_type)).to include("split")
      expect(parent.task_events.last.payload_json).to include(
        "child_task_id" => child.id,
        "source_planned_occurrence_id" => planned_occurrence.id
      )

      expect(child.parent_task).to eq(parent)
      expect(child.root_task).to eq(parent)
      expect(child.responsible_id).to eq(42)
      expect(child.recurrence_rule.execution_time.strftime("%H:%M")).to eq("14:00")
      expect(child.task_occurrences.where(status: :planned).pluck(:scheduled_at)).to eq([ Time.zone.parse("2026-05-12 14:00") ])
      expect(child.next_run_at).to eq(Time.zone.parse("2026-05-12 14:00"))
      expect(child.task_events.pluck(:event_type)).to include("created")
    end
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
end
