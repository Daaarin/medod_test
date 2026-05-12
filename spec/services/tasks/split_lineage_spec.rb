require "rails_helper"

RSpec.describe Tasks::SplitLineage do
  it "retires the parent, preserves the lineage root, and copies the recurrence rule to the child" do
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

    child = described_class.call(
      task: parent,
      end_reason: :responsible_changed,
      responsible_id: 77
    )

    expect(parent.reload).to be_final
    expect(parent.status).to eq("cancelled")
    expect(parent.end_reason).to eq("responsible_changed")
    expect(parent.cancelled_at).to be_present

    expect(child.parent_task).to eq(parent)
    expect(child.root_task).to eq(parent)
    expect(child.responsible_id).to eq(77)
    expect(child.status).to eq("ongoing")
    expect(child.description).to eq("Daily review")
    expect(child.next_run_at).to eq(Time.zone.parse("2026-05-12 10:00"))
    expect(child.recurrence_rule).to be_present
    expect(child.recurrence_rule.rule_type).to eq("every_n_days")
    expect(child.recurrence_rule.interval_value).to eq(1)
  end

  it "uses supplied recurrence rule attributes when provided" do
    parent = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    parent.create_recurrence_rule!(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    child = described_class.call(
      task: parent,
      end_reason: :schedule_changed,
      recurrence_rule_attributes: {
        rule_type: :weekday_parity,
        weekday_parity: :even,
        execution_time: "14:00",
        timezone: "Europe/Moscow",
        date_start: Date.new(2026, 5, 12)
      }
    )

    expect(child.recurrence_rule.rule_type).to eq("weekday_parity")
    expect(child.recurrence_rule.weekday_parity).to eq("even")
    expect(child.recurrence_rule.execution_time.strftime("%H:%M")).to eq("14:00")
  end
end
