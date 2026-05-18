# == Schema Information
#
# Table name: recurrence_rules
#
#  id                  :bigint           not null, primary key
#  date_end            :date
#  date_start          :date             not null
#  day_of_month        :integer
#  day_of_month_parity :string
#  execution_time      :time             not null
#  interval_value      :integer
#  month_of_year       :integer
#  rule_type           :string           not null
#  timezone            :string           not null
#  weekday             :integer
#  weekday_parity      :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  task_id             :bigint           not null
#
# Indexes
#
#  index_recurrence_rules_on_rule_type  (rule_type)
#  index_recurrence_rules_on_task_id    (task_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (task_id => tasks.id)
#
require "rails_helper"

RSpec.describe RecurrenceRule, type: :model do
  it "exposes the supported recurrence shapes" do
    expect(described_class.rule_types.keys).to match_array(
      %w[every_n_days every_n_months every_n_years day_of_month_parity weekday_parity specific_dates]
    )
  end

  it "accepts parity-based day and weekday selectors" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
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
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
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
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :one_time,
      status: :ongoing,
      name: "Send email",
      responsible: responsible
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
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
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
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
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
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
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
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
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

  it "accepts specific dates when at least one date is present and in range" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    rule = task.build_recurrence_rule(
      rule_type: :specific_dates,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1),
      date_end: Date.new(2026, 5, 31),
      recurrence_rule_dates_attributes: [
        { run_date: Date.new(2026, 5, 12) }
      ]
    )

    expect(rule).to be_valid
  end

  it "rejects specific dates without any recurrence_rule_date entries" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    rule = task.build_recurrence_rule(
      rule_type: :specific_dates,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:recurrence_rule_dates]).to include("must include at least one date")
  end

  it "rejects specific dates outside the recurrence window" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    rule = task.build_recurrence_rule(
      rule_type: :specific_dates,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 10),
      date_end: Date.new(2026, 5, 20),
      recurrence_rule_dates_attributes: [
        { run_date: Date.new(2026, 5, 9) },
        { run_date: Date.new(2026, 5, 21) }
      ]
    )

    expect(rule).not_to be_valid
    expect(rule.recurrence_rule_dates.first.errors[:run_date]).to include("must be on or after date_start")
    expect(rule.recurrence_rule_dates.second.errors[:run_date]).to include("must be on or before date_end")
  end

  it "rejects duplicate nested specific dates before persistence" do
    responsible = build_user(email: "responsible-specific-duplicates@example.test", role: :doctor)
    task = Task.new(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
    rule = task.build_recurrence_rule(
      rule_type: :specific_dates,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1),
      recurrence_rule_dates_attributes: [
        { run_date: Date.new(2026, 5, 12) },
        { run_date: Date.new(2026, 5, 12) }
      ]
    )

    expect(rule).not_to be_valid
    expect(rule.errors[:recurrence_rule_dates]).to include("must not include duplicate dates")
    expect { rule.save! }.to raise_error(ActiveRecord::RecordInvalid, /duplicate dates/)
  end

  it "requires parity selectors for parity-based rules" do
    responsible = build_user(email: "responsible@example.test", role: :doctor)
    task = Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
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
