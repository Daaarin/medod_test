class TaskTag < ApplicationRecord
  belongs_to :task
  belongs_to :tag

  scope :active, -> { where(deactivated_at: nil) }

  validates :task_id, uniqueness: { scope: :tag_id }
  before_destroy :prevent_destroy

  def active?
    deactivated_at.blank?
  end

  def deactivate!
    update!(deactivated_at: Time.current)
  end

  def reactivate!
    update!(deactivated_at: nil)
  end

  class << self
    def attach!(task:, tag:)
      task_tag = find_or_initialize_by(task: task, tag: tag)
      task_tag.deactivated_at = nil
      task_tag.save!
      task_tag
    end

    def detach!(task:, tag:)
      task_tag = find_by(task: task, tag: tag)
      raise ActiveRecord::RecordNotFound, "Task tag not found" unless task_tag

      task_tag.deactivate!
      task_tag
    end
  end

  private

    def prevent_destroy
      errors.add(:base, "task tags must be deactivated instead of deleted")
      throw :abort
    end
end
