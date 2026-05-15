class Tag < ApplicationRecord
  has_many :task_tags, dependent: :restrict_with_exception, inverse_of: :tag
  has_many :tasks, through: :task_tags

  scope :active, -> { where(deactivated_at: nil) }

  validates :name, presence: true
  before_update :prevent_system_tag_mutation, if: :persisted_system_tag?
  before_destroy :prevent_destroy

  def active?
    deactivated_at.blank?
  end

  def system_tag?
    is_system_tag
  end

  def deactivate!
    raise ActiveRecord::RecordInvalid, self unless deactivate

    true
  end

  def deactivate
    timestamp = Time.current
    success = false

    transaction do
      success = update(deactivated_at: timestamp)
      raise ActiveRecord::Rollback unless success

      task_tags.active.update_all(deactivated_at: timestamp, updated_at: timestamp)
    end

    success
  end

  private

    def persisted_system_tag?
      is_system_tag_in_database
    end

    def prevent_system_tag_mutation
      errors.add(:base, "system tags cannot be renamed, deactivated, or deleted")
      throw :abort
    end

    def prevent_destroy
      errors.add(:base, "tags must be deactivated instead of deleted")
      throw :abort
    end
end
