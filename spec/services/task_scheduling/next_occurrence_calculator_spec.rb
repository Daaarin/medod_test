require "rails_helper"

RSpec.describe TaskScheduling::NextOccurrenceCalculator do
  let(:zone) { ActiveSupport::TimeZone["Europe/Moscow"] }

  it "returns the scheduled time for a one-time task when it is not before the requested time" do
    task = Task.new(
      task_kind: :one_time,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42,
      next_run_at: zone.parse("2026-05-12 10:00")
    )

    result = described_class.call(task: task, from_time: zone.parse("2026-05-12 09:00"))

    expect(result).to eq(zone.parse("2026-05-12 10:00"))
  end

  it "finds the next every_n_days occurrence" do
    task = build_recurring_task(
      rule_type: :every_n_days,
      interval_value: 2,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    result = described_class.call(task: task, from_time: zone.parse("2026-05-11 09:00"))

    expect(result).to eq(zone.parse("2026-05-11 10:00"))
  end

  it "finds the next every_n_months occurrence and clamps invalid month days" do
    task = build_recurring_task(
      rule_type: :every_n_months,
      interval_value: 1,
      day_of_month: 31,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 1, 31)
    )

    result = described_class.call(task: task, from_time: zone.parse("2026-02-01 00:00"))

    expect(result).to eq(zone.parse("2026-02-28 10:00"))
  end

  it "finds the next every_n_years occurrence and clamps invalid leap days" do
    task = build_recurring_task(
      rule_type: :every_n_years,
      interval_value: 1,
      month_of_year: 2,
      day_of_month: 29,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2024, 2, 29)
    )

    result = described_class.call(task: task, from_time: zone.parse("2025-01-01 00:00"))

    expect(result).to eq(zone.parse("2025-02-28 10:00"))
  end

  it "finds the next even day-of-month occurrence" do
    task = build_recurring_task(
      rule_type: :day_of_month_parity,
      day_of_month_parity: :even,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    result = described_class.call(task: task, from_time: zone.parse("2026-05-11 09:00"))

    expect(result).to eq(zone.parse("2026-05-12 10:00"))
  end

  it "finds the next odd ISO weekday occurrence" do
    task = build_recurring_task(
      rule_type: :weekday_parity,
      weekday_parity: :odd,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    result = described_class.call(task: task, from_time: zone.parse("2026-05-11 09:00"))

    expect(result).to eq(zone.parse("2026-05-11 10:00"))
  end

  it "returns nil after the series is exhausted" do
    task = build_recurring_task(
      rule_type: :every_n_days,
      interval_value: 2,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1),
      date_end: Date.new(2026, 5, 5)
    )

    result = described_class.call(task: task, from_time: zone.parse("2026-05-06 00:00"))

    expect(result).to be_nil
  end

  def build_recurring_task(**rule_attributes)
    task = Task.new(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    task.build_recurrence_rule(rule_attributes)
    task
  end
end
