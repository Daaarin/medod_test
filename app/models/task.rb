# == Schema Information
#
# Table name: tasks
#
#  id                  :bigint           not null, primary key
#  accepted_at         :datetime
#  cancellation_reason :string
#  cancelled_at        :datetime
#  completed_at        :datetime
#  completion_date     :date
#  deactivated_at      :datetime
#  description         :text
#  end_reason          :string
#  first_run_at        :datetime
#  name                :string           not null
#  next_run_at         :datetime
#  status              :string           not null
#  task_kind           :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  creator_id          :bigint
#  delegated_user_id   :bigint
#  parent_task_id      :bigint
#  responsible_id      :bigint
#  root_task_id        :bigint
#
# Indexes
#
#  index_tasks_on_creator_id         (creator_id)
#  index_tasks_on_delegated_user_id  (delegated_user_id)
#  index_tasks_on_next_run_at        (next_run_at)
#  index_tasks_on_parent_task_id     (parent_task_id)
#  index_tasks_on_responsible_id     (responsible_id)
#  index_tasks_on_root_task_id       (root_task_id)
#  index_tasks_on_status             (status)
#  index_tasks_on_task_kind          (task_kind)
#
# Foreign Keys
#
#  fk_rails_...  (creator_id => users.id)
#  fk_rails_...  (delegated_user_id => users.id)
#  fk_rails_...  (parent_task_id => tasks.id)
#  fk_rails_...  (responsible_id => users.id)
#  fk_rails_...  (root_task_id => tasks.id)
#
class Task < ApplicationRecord
  belongs_to :parent_task, class_name: "Task", optional: true, inverse_of: :child_tasks
  belongs_to :root_task, class_name: "Task", optional: true
  belongs_to :creator, class_name: "User", optional: true, inverse_of: :created_tasks
  belongs_to :responsible, class_name: "User", optional: true, inverse_of: :responsible_tasks
  belongs_to :delegated_user, class_name: "User", optional: true, inverse_of: :delegated_tasks

  has_many :child_tasks, class_name: "Task", foreign_key: :parent_task_id, inverse_of: :parent_task, dependent: :nullify
  has_one :recurrence_rule, dependent: :destroy, inverse_of: :task
  has_many :task_occurrences, dependent: :destroy, inverse_of: :task
  has_many :task_events, dependent: :destroy, inverse_of: :task
  has_many :task_tags, inverse_of: :task
  has_many :tags, through: :task_tags
  accepts_nested_attributes_for :recurrence_rule

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
    schedule_changed: "schedule_changed",
    declined: "declined"
  }, validate: { allow_nil: true }

  validates :task_kind, :status, :name, presence: true
  validate :ownership_context_required
  validate :end_reason_required_for_final_tasks
  validate :one_time_tasks_must_not_have_recurrence_rule
  before_validation :normalize_one_time_schedule_from_completion_date
  before_validation :normalize_recurring_end_date
  validate :completion_date_must_follow_initial_schedule
  before_update :prevent_mutation_when_final
  before_destroy :prevent_destroy

  def active?
    !final? && deactivated_at.blank?
  end

  def final?
    completed? || cancelled?
  end

  def retire!(end_reason:, cancelled_at: Time.current, cancellation_reason: nil)
    cancellation_reason = cancellation_reason.presence || end_reason.to_s

    update!(
      status: :cancelled,
      end_reason: end_reason,
      cancelled_at: cancelled_at,
      cancellation_reason: cancellation_reason
    )
  end

  def effective_completion_date
    completion_date || recurrence_rule&.date_end
  end

  def effective_recurrence_end_date
    recurrence_rule&.date_end || completion_date
  end

  private

    def normalize_one_time_schedule_from_completion_date
      return unless one_time?
      return if completion_date.blank?
      return if first_run_at.present? || next_run_at.present?

      normalized_time = Time.zone.local(
        completion_date.year,
        completion_date.month,
        completion_date.day,
        12,
        0,
        0
      )

      self.first_run_at = normalized_time
      self.next_run_at = normalized_time
    end

    def end_reason_required_for_final_tasks
      return unless final? && end_reason.blank?

      errors.add(:end_reason, "must be present for final tasks")
    end

    def ownership_context_required
      return if creator_id.present? || responsible_id.present? || delegated_user_id.present?

      errors.add(:base, "must have a creator, responsible user, or delegated user")
    end

    def one_time_tasks_must_not_have_recurrence_rule
      return unless one_time? && recurrence_rule.present?

      errors.add(:recurrence_rule, "must be absent for one-time tasks")
    end

    def normalize_recurring_end_date
      return unless recurring? && recurrence_rule.present?

      completion_date_changed = will_save_change_to_completion_date?
      recurrence_end_changed = recurrence_rule.will_save_change_to_date_end?
      return unless completion_date_changed || recurrence_end_changed

      completion_end_date = completion_date
      recurrence_end_date = recurrence_rule.date_end

      if completion_date_changed && recurrence_end_changed && completion_end_date != recurrence_end_date
        errors.add(:completion_date, "must match recurrence end date")
        errors.add(:base, "recurrence_rule.date_end must match completion_date")
        throw :abort
      end

      effective_end_date = completion_date_changed ? completion_end_date : recurrence_end_date
      self.completion_date = effective_end_date
      recurrence_rule.date_end = effective_end_date
    end

    def completion_date_must_follow_initial_schedule
      return if completion_date.blank?

      scheduled_times = [ first_run_at, next_run_at ]
      scheduled_times << initial_recurring_run_at if recurring?
      latest_schedule_time = scheduled_times.compact.max
      return if latest_schedule_time.blank?
      return if completion_date >= latest_schedule_time.to_date

      errors.add(:base, "completion_date must be on or after the first or next run")
    end

    def initial_recurring_run_at
      return unless recurring? && recurrence_rule.present?
      return if recurrence_rule.date_start.blank?

      TaskScheduling::NextOccurrenceCalculator.call(
        task: self,
        from_time: first_run_at || recurrence_rule.date_start.beginning_of_day
      )
    end

    def prevent_mutation_when_final
      return unless persisted_final?

      errors.add(:base, "final tasks are immutable")
      throw :abort
    end

    def prevent_destroy
      errors.add(:base, "tasks cannot be hard-deleted; deactivate them instead")
      throw :abort
    end

    def persisted_final?
      status_in_database.in?(%w[completed cancelled])
    end
end
