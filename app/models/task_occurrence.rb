class TaskOccurrence < ApplicationRecord
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
  validate :task_may_have_only_one_planned_occurrence, if: :planned?

  private

    def task_may_have_only_one_planned_occurrence
      return unless task_id.present? && self.class.where(task_id: task_id, status: :planned).where.not(id: id).exists?

      errors.add(:task_id, "already has a planned occurrence")
    end
end
