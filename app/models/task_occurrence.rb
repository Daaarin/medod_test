# == Schema Information
#
# Table name: task_occurrences
#
#  id           :bigint           not null, primary key
#  actual_at    :datetime
#  generated_at :datetime
#  postponed_to :datetime
#  scheduled_at :datetime         not null
#  skip_reason  :string
#  status       :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  task_id      :bigint           not null
#
# Indexes
#
#  index_task_occurrences_on_task_id               (task_id)
#  index_task_occurrences_on_task_id_and_status    (task_id,status)
#  index_task_occurrences_on_task_id_when_current  (task_id) UNIQUE WHERE ((status)::text = ANY ((ARRAY['planned'::character varying, 'postponed'::character varying])::text[]))
#
# Foreign Keys
#
#  fk_rails_...  (task_id => tasks.id)
#
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
