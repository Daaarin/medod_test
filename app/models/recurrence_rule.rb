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
  validate :rule_specific_requirements
  validate :timezone_must_be_known
  validate :date_window_is_ordered

  private

    def rule_specific_requirements
      errors.add(:day_of_month, "must be between 1 and 31") if day_of_month.present? && !day_of_month.between?(1, 31)
      errors.add(:month_of_year, "must be between 1 and 12") if month_of_year.present? && !month_of_year.between?(1, 12)
      errors.add(:weekday, "must be between 1 and 7") if weekday.present? && !weekday.between?(1, 7)

      case rule_type
        when "every_n_days", "every_n_months", "every_n_years"
          errors.add(:interval_value, "must be greater than 0") if interval_value.blank? || interval_value <= 0
        when "day_of_month_parity"
          errors.add(:day_of_month_parity, "must be present") if day_of_month_parity.blank?
        when "weekday_parity"
          errors.add(:weekday_parity, "must be present") if weekday_parity.blank?
      end
    end

    def timezone_must_be_known
      return if timezone.blank? || ActiveSupport::TimeZone[timezone]

      errors.add(:timezone, "is not a valid time zone")
    end

    def date_window_is_ordered
      return if date_start.blank? || date_end.blank? || date_end >= date_start

      errors.add(:date_end, "must be on or after date_start")
    end
end
