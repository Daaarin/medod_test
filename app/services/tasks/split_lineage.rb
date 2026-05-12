module Tasks
  class SplitLineage
    class << self
      def call(task:, end_reason:, responsible_id: nil, recurrence_rule_attributes: nil)
        new(task:, end_reason:, responsible_id:, recurrence_rule_attributes:).call
      end
    end

    def initialize(task:, end_reason:, responsible_id:, recurrence_rule_attributes:)
      @task = task
      @end_reason = end_reason
      @responsible_id = responsible_id
      @recurrence_rule_attributes = recurrence_rule_attributes
    end

    def call
      Task.transaction do
        child = build_child_task
        child.save!

        finalize_parent!

        child
      end
    end

    private

    attr_reader :task, :end_reason, :responsible_id, :recurrence_rule_attributes

    def build_child_task
      child = Task.new(
        task_kind: task.task_kind,
        status: task.status,
        end_reason: nil,
        title: task.title,
        description: task.description,
        responsible_id: responsible_id || task.responsible_id,
        first_run_at: task.first_run_at,
        next_run_at: task.next_run_at,
        parent_task: task,
        root_task: task.root_task || task
      )

      copy_recurrence_rule(child)

      child
    end

    def copy_recurrence_rule(child)
      attributes = recurrence_rule_attributes.presence || existing_recurrence_rule_attributes
      return unless attributes

      child.build_recurrence_rule(attributes)
    end

    def finalize_parent!
      timestamp = Time.current
      task.update_columns(
        status: Task.statuses.fetch("cancelled"),
        end_reason: Task.end_reasons.fetch(end_reason.to_s),
        cancelled_at: timestamp,
        updated_at: timestamp
      )
    end

    def existing_recurrence_rule_attributes
      rule = task.recurrence_rule
      return nil unless rule

      rule.attributes.except("id", "task_id", "created_at", "updated_at")
    end
  end
end
