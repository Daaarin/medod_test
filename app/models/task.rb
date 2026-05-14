class Task < ApplicationRecord
  belongs_to :parent_task, class_name: "Task", optional: true, inverse_of: :child_tasks
  belongs_to :root_task, class_name: "Task", optional: true

  has_many :child_tasks, class_name: "Task", foreign_key: :parent_task_id, inverse_of: :parent_task, dependent: :nullify
  has_one :recurrence_rule, dependent: :destroy, inverse_of: :task
  has_many :task_occurrences, dependent: :destroy, inverse_of: :task
  has_many :task_events, dependent: :destroy, inverse_of: :task

  enum :task_kind, { one_time: "one_time", recurring: "recurring" }, validate: true
  enum :status, {
    draft: "draft",
    pending_acceptance: "pending_acceptance",
    ongoing: "ongoing",
    completed: "completed",
    cancelled: "cancelled"
  }, validate: true
  enum :end_reason, {
    series_completed: "series_completed",
    manual_cancelled: "manual_cancelled",
    responsible_changed: "responsible_changed",
    schedule_changed: "schedule_changed"
  }, validate: { allow_nil: true }

  validates :task_kind, :status, :title, :responsible_id, presence: true
  validate :end_reason_required_for_final_tasks
  validate :one_time_tasks_must_not_have_recurrence_rule
  before_update :prevent_mutation_when_final
  before_destroy :prevent_mutation_when_final

  def active?
    !final?
  end

  def final?
    completed? || cancelled?
  end

  def retire!(end_reason:)
    update!(status: :cancelled, end_reason: end_reason)
  end

  private

    def end_reason_required_for_final_tasks
      return unless final? && end_reason.blank?

      errors.add(:end_reason, "must be present for final tasks")
    end

    def one_time_tasks_must_not_have_recurrence_rule
      return unless one_time? && recurrence_rule.present?

      errors.add(:recurrence_rule, "must be absent for one-time tasks")
    end

    def prevent_mutation_when_final
      return unless persisted_final?

      errors.add(:base, "final tasks are immutable")
      throw :abort
    end

    def persisted_final?
      status_in_database.in?(%w[completed cancelled])
    end
end
