require "rails_helper"

RSpec.describe TaskScheduling::NextOccurrenceCalculator do
  let(:zone) { ActiveSupport::TimeZone["Europe/Moscow"] }

  it "returns the scheduled time for a one-time task when it is not before the requested time" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.new(
      task_kind: :one_time,
      status: :ongoing,
      name: "Check email",
      responsible: responsible,
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

  it "keeps every_n_days aligned across a spring-forward DST transition" do
    new_york = ActiveSupport::TimeZone["America/New_York"]
    task = build_recurring_task(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "02:30",
      timezone: "America/New_York",
      date_start: Date.new(2026, 3, 7)
    )

    first = described_class.call(task: task, from_time: new_york.parse("2026-03-07 00:00"))
    second = described_class.call(task: task, from_time: new_york.parse("2026-03-07 02:31"))
    third = described_class.call(task: task, from_time: new_york.parse("2026-03-08 03:31"))

    expect([ first, second, third ]).to eq(
      [
        new_york.parse("2026-03-07 02:30"),
        new_york.parse("2026-03-08 03:30"),
        new_york.parse("2026-03-09 02:30")
      ]
    )
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

  it "finds the next specific date occurrence in run_date order" do
    task = build_recurring_task(
      rule_type: :specific_dates,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1),
      recurrence_rule_dates_attributes: [
        { run_date: Date.new(2026, 5, 20) },
        { run_date: Date.new(2026, 5, 11) },
        { run_date: Date.new(2026, 5, 15) }
      ]
    )

    result = described_class.call(task: task, from_time: zone.parse("2026-05-01 00:00"))

    expect(result).to eq(zone.parse("2026-05-11 10:00"))
  end

  it "returns nil after the last specific date occurrence" do
    task = build_recurring_task(
      rule_type: :specific_dates,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1),
      date_end: Date.new(2026, 5, 15),
      recurrence_rule_dates_attributes: [
        { run_date: Date.new(2026, 5, 11) },
        { run_date: Date.new(2026, 5, 15) }
      ]
    )

    result = described_class.call(task: task, from_time: zone.parse("2026-05-16 00:00"))

    expect(result).to be_nil
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
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.new(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    task.build_recurrence_rule(rule_attributes)
    task
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
