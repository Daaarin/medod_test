require "rails_helper"

RSpec.describe RecurrenceRule, type: :model do
  it "exposes the supported recurrence shapes" do
    expect(described_class.rule_types.keys).to match_array(
      %w[every_n_days every_n_months every_n_years day_of_month_parity weekday_parity]
    )
  end

  it "accepts parity-based day and weekday selectors" do
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    rule = task.build_recurrence_rule(
      rule_type: :day_of_month_parity,
      day_of_month_parity: :even,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    expect(rule).to be_valid
  end

  it "rejects unsupported time zones" do
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    rule = task.build_recurrence_rule(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "10:00",
      timezone: "Mars/Olympus",
      date_start: Date.new(2026, 5, 1)
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:timezone]).to include("is not a valid time zone")
  end

  it "rejects rules attached directly to one-time tasks" do
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      title: "Send email",
      responsible_id: 42
    )
    rule = task.build_recurrence_rule(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:task]).to include("must be recurring")
  end

  it "requires positive intervals for interval-based rules" do
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    rule = task.build_recurrence_rule(
      rule_type: :every_n_days,
      interval_value: 0,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:interval_value]).to include("must be greater than 0")
  end

  it "rejects out-of-range calendar selectors" do
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    rule = task.build_recurrence_rule(
      rule_type: :day_of_month_parity,
      interval_value: 1,
      day_of_month: 32,
      month_of_year: 13,
      day_of_month_parity: :even,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:day_of_month]).to include("must be between 1 and 31")
    expect(rule.errors[:month_of_year]).to include("must be between 1 and 12")
  end

  it "rejects invalid weekday values" do
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    rule = task.build_recurrence_rule(
      rule_type: :weekday_parity,
      weekday_parity: :odd,
      weekday: 9,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:weekday]).to include("must be between 1 and 7")
  end

  it "rejects inverted date windows" do
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    rule = task.build_recurrence_rule(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 10),
      date_end: Date.new(2026, 5, 1)
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:date_end]).to include("must be on or after date_start")
  end

  it "requires parity selectors for parity-based rules" do
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      title: "Check email",
      responsible_id: 42
    )
    rule = task.build_recurrence_rule(
      rule_type: :weekday_parity,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:weekday_parity]).to include("must be present")
  end
end
