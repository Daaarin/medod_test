class RecurrenceRuleDate < ApplicationRecord
  belongs_to :recurrence_rule, inverse_of: :recurrence_rule_dates

  validates :run_date, presence: true
  validates :run_date, uniqueness: { scope: :recurrence_rule_id }
  validate :recurrence_rule_must_use_specific_dates
  validate :run_date_must_respect_rule_window

  private

    def recurrence_rule_must_use_specific_dates
      return if recurrence_rule.blank? || recurrence_rule.specific_dates?

      errors.add(:recurrence_rule, "must use specific_dates")
    end

    def run_date_must_respect_rule_window
      return if run_date.blank? || recurrence_rule.blank?
      return unless recurrence_rule.specific_dates?

      if recurrence_rule.date_start.present? && run_date < recurrence_rule.date_start
        errors.add(:run_date, "must be on or after date_start")
      end

      if recurrence_rule.date_end.present? && run_date > recurrence_rule.date_end
        errors.add(:run_date, "must be on or before date_end")
      end
    end
end
