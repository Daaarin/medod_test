# == Schema Information
#
# Table name: task_tags
#
#  id             :bigint           not null, primary key
#  deactivated_at :datetime
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  tag_id         :bigint           not null
#  task_id        :bigint           not null
#
# Indexes
#
#  index_task_tags_on_tag_id              (tag_id)
#  index_task_tags_on_task_id             (task_id)
#  index_task_tags_on_task_id_and_tag_id  (task_id,tag_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (tag_id => tags.id)
#  fk_rails_...  (task_id => tasks.id)
#
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
