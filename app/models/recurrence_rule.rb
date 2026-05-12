class RecurrenceRule < ApplicationRecord
  belongs_to :task, inverse_of: :recurrence_rule

  enum :rule_type, {
    every_n_days: "every_n_days",
    every_n_months: "every_n_months",
    every_n_years: "every_n_years",
    day_of_month_parity: "day_of_month_parity",
    weekday_parity: "weekday_parity"
  }, validate: true

  enum :day_of_month_parity, { even: "even", odd: "odd" }, prefix: true, validate: { allow_nil: true }
  enum :weekday_parity, { even: "even", odd: "odd" }, prefix: true, validate: { allow_nil: true }

  validates :rule_type, :execution_time, :timezone, :date_start, presence: true
end
