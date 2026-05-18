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
class RecurrenceRule < ApplicationRecord
  belongs_to :task, inverse_of: :recurrence_rule
  has_many :recurrence_rule_dates, inverse_of: :recurrence_rule, dependent: :destroy
  accepts_nested_attributes_for :recurrence_rule_dates, reject_if: :all_blank

  enum :rule_type, {
    every_n_days: "every_n_days",
    every_n_months: "every_n_months",
    every_n_years: "every_n_years",
    day_of_month_parity: "day_of_month_parity",
    weekday_parity: "weekday_parity",
    specific_dates: "specific_dates"
  }, validate: true

  enum :day_of_month_parity, { even: "even", odd: "odd" }, prefix: true, validate: { allow_nil: true }
  enum :weekday_parity, { even: "even", odd: "odd" }, prefix: true, validate: { allow_nil: true }

  validates :rule_type, :execution_time, :timezone, :date_start, presence: true
  validate :rule_specific_requirements
  validate :timezone_must_be_known
  validate :date_window_is_ordered
  validate :task_must_be_recurring
  validate :specific_dates_require_entries
  validate :specific_dates_must_be_unique

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

    def task_must_be_recurring
      return if task.blank? || task.recurring?

      errors.add(:task, "must be recurring")
    end

    def specific_dates_require_entries
      return unless specific_dates?

      errors.add(:recurrence_rule_dates, "must include at least one date") if recurrence_rule_dates.reject(&:marked_for_destruction?).empty?
    end

    def specific_dates_must_be_unique
      return unless specific_dates?

      dates = recurrence_rule_dates.reject(&:marked_for_destruction?).filter_map(&:run_date)
      return if dates.uniq.size == dates.size

      errors.add(:recurrence_rule_dates, "must not include duplicate dates")
    end
end
