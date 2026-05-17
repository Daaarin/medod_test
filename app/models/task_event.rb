# == Schema Information
#
# Table name: task_events
#
#  id            :bigint           not null, primary key
#  event_type    :string           not null
#  occurred_at   :datetime         not null
#  payload_json  :jsonb            not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  actor_id      :bigint           not null
#  occurrence_id :bigint
#  task_id       :bigint           not null
#
# Indexes
#
#  index_task_events_on_actor_id       (actor_id)
#  index_task_events_on_event_type     (event_type)
#  index_task_events_on_occurred_at    (occurred_at)
#  index_task_events_on_occurrence_id  (occurrence_id)
#  index_task_events_on_task_id        (task_id)
#
# Foreign Keys
#
#  fk_rails_...  (occurrence_id => task_occurrences.id)
#  fk_rails_...  (task_id => tasks.id)
#
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
