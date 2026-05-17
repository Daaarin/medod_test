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
      effective_date_end = recurrence_rule.task&.effective_recurrence_end_date

      if recurrence_rule.date_start.present? && run_date < recurrence_rule.date_start
        errors.add(:run_date, "must be on or after date_start")
      end

      if effective_date_end.present? && run_date > effective_date_end
        errors.add(:run_date, "must be on or before date_end")
      end
    end
end
