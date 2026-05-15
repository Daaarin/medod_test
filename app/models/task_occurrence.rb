class TaskOccurrence < ApplicationRecord
  CURRENT_STATUSES = %w[planned postponed].freeze

  belongs_to :task, inverse_of: :task_occurrences

  enum :status, {
    planned: "planned",
    postponed: "postponed",
    executed: "executed",
    skipped: "skipped",
    superseded: "superseded",
    cancelled: "cancelled"
  }, validate: true

  validates :scheduled_at, :status, presence: true
  validate :task_may_have_only_one_current_occurrence, if: :current_occurrence?

  def current?
    planned? || postponed?
  end

  def actionable_time
    postponed_to || scheduled_at
  end

  private

    def current_occurrence?
      current?
    end

    def task_may_have_only_one_current_occurrence
      return unless task_id.present? && self.class.where(task_id: task_id, status: CURRENT_STATUSES).where.not(id: id).exists?

      errors.add(:task_id, "already has a current occurrence")
    end
end
