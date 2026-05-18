# == Schema Information
#
# Table name: recurrence_rule_dates
#
#  id                 :bigint           not null, primary key
#  run_date           :date             not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  recurrence_rule_id :bigint           not null
#
# Indexes
#
#  index_recurrence_rule_dates_on_recurrence_rule_id  (recurrence_rule_id)
#  index_recurrence_rule_dates_on_rule_and_run_date   (recurrence_rule_id,run_date) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (recurrence_rule_id => recurrence_rules.id)
#
require "rails_helper"

RSpec.describe RecurrenceRuleDate, type: :model do
  it "allows specific_dates rows inside the parent rule window" do
    rule = build_specific_dates_rule(
      date_start: Date.new(2026, 5, 1),
      date_end: Date.new(2026, 5, 31)
    )

    recurrence_rule_date = rule.recurrence_rule_dates.build(run_date: Date.new(2026, 5, 12))

    expect(recurrence_rule_date).to be_valid
  end

  it "rejects dates before the rule start" do
    rule = build_specific_dates_rule(
      date_start: Date.new(2026, 5, 10),
      date_end: Date.new(2026, 5, 31)
    )

    recurrence_rule_date = rule.recurrence_rule_dates.build(run_date: Date.new(2026, 5, 9))

    expect(recurrence_rule_date).not_to be_valid
    expect(recurrence_rule_date.errors[:run_date]).to include("must be on or after date_start")
  end

  it "rejects dates after the rule end" do
    rule = build_specific_dates_rule(
      date_start: Date.new(2026, 5, 1),
      date_end: Date.new(2026, 5, 20)
    )

    recurrence_rule_date = rule.recurrence_rule_dates.build(run_date: Date.new(2026, 5, 21))

    expect(recurrence_rule_date).not_to be_valid
    expect(recurrence_rule_date.errors[:run_date]).to include("must be on or before date_end")
  end

  it "rejects being attached to a non-specific rule" do
    rule = build_interval_rule

    recurrence_rule_date = rule.recurrence_rule_dates.build(run_date: Date.new(2026, 5, 12))

    expect(recurrence_rule_date).not_to be_valid
    expect(recurrence_rule_date.errors[:recurrence_rule]).to include("must use specific_dates")
  end

  def build_specific_dates_rule(date_start:, date_end: nil)
    build_task.build_recurrence_rule(
      rule_type: :specific_dates,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: date_start,
      date_end: date_end
    )
  end

  def build_interval_rule
    build_task.build_recurrence_rule(
      rule_type: :every_n_days,
      interval_value: 1,
      execution_time: "10:00",
      timezone: "Europe/Moscow",
      date_start: Date.new(2026, 5, 1)
    )
  end

  def build_task
    responsible = User.create!(
      email: "responsible-#{SecureRandom.hex(4)}@example.test",
      password: "password123",
      role: :doctor,
      name: "Test",
      last_name: "User"
    )

    Task.create!(
      task_kind: :recurring,
      status: :ongoing,
      name: "Check email",
      responsible: responsible
    )
  end
end
