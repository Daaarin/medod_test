class TaskEvent < ApplicationRecord
  belongs_to :task, inverse_of: :task_events
  belongs_to :occurrence, class_name: "TaskOccurrence", optional: true

  enum :event_type, {
    created: "created",
    accepted: "accepted",
    metadata_changed: "metadata_changed",
    executed: "executed",
    skipped: "skipped",
    postponed: "postponed",
    completed: "completed",
    cancelled: "cancelled",
    split: "split"
  }, prefix: true, validate: true

  validates :event_type, :actor_id, :occurred_at, presence: true
  validate :occurrence_must_belong_to_task
  before_update :prevent_mutation
  before_destroy :prevent_mutation

  private

    def occurrence_must_belong_to_task
      return unless occurrence && occurrence.task_id != task_id

      errors.add(:occurrence, "must belong to the same task")
    end

    def prevent_mutation
      errors.add(:base, "task events are append-only")
      throw :abort
    end
end
