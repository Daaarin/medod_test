module Tasks
  class SplitLineage
    class << self
      def call(task:, end_reason:, responsible_id: nil, recurrence_rule_attributes: nil, actor_id: nil)
        new(
          task:,
          end_reason:,
          responsible_id:,
          recurrence_rule_attributes:,
          actor_id:
        ).call
      end
    end

    def initialize(task:, end_reason:, responsible_id:, recurrence_rule_attributes:, actor_id:)
      @task = task
      @end_reason = end_reason
      @responsible_id = responsible_id
      @recurrence_rule_attributes = recurrence_rule_attributes
      @actor_id = actor_id
    end

    def call
      Task.transaction do
        task.with_lock do
          raise ArgumentError, "task must be active" unless task.active?

          child = build_child_task
          child.save!

          child_occurrence = replace_planned_occurrence!(child)
          append_audit_events!(child, child_occurrence)

          finalize_parent!

          child
        end
      end
    end

    private

    attr_reader :task, :end_reason, :responsible_id, :recurrence_rule_attributes, :actor_id, :source_planned_occurrence

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

    def replace_planned_occurrence!(child)
      planned_occurrence = lock_parent_planned_occurrence
      @source_planned_occurrence = planned_occurrence
      return supersede_parent_and_create_child_occurrence!(child, planned_occurrence) if end_reason.to_s == "schedule_changed"

      transfer_planned_occurrence_to_child!(child, planned_occurrence)
    end

    def transfer_planned_occurrence_to_child!(child, planned_occurrence)
      return create_child_planned_occurrence!(child) unless planned_occurrence

      planned_occurrence.update!(task: child)
      child.update!(next_run_at: planned_occurrence.scheduled_at)
      planned_occurrence
    end

    def supersede_parent_and_create_child_occurrence!(child, planned_occurrence)
      planned_occurrence&.update!(
        status: :superseded
      )

      create_child_planned_occurrence!(child)
    end

    def create_child_planned_occurrence!(child)
      occurrence_time = next_child_occurrence_time(child)
      return nil unless occurrence_time

      child.task_occurrences.create!(
        scheduled_at: occurrence_time,
        status: :planned,
        generated_at: Time.current
      ).tap do |occurrence|
        child.update!(next_run_at: occurrence.scheduled_at)
      end
    end

    def next_child_occurrence_time(child)
      TaskScheduling::NextOccurrenceCalculator.call(task: child, from_time: Time.current)
    end

    def lock_parent_planned_occurrence
      task.task_occurrences.where(status: :planned).lock.first
    end

    def append_audit_events!(child, child_occurrence)
      audit_actor_id = actor_id || task.responsible_id

      Tasks::AppendEvent.call(
        task: task,
        event_type: :split,
        actor_id: audit_actor_id,
        payload: parent_split_payload(child:, child_occurrence:)
      )

      Tasks::AppendEvent.call(
        task: child,
        occurrence: child_occurrence,
        event_type: :created,
        actor_id: audit_actor_id,
        payload: child_created_payload(child_occurrence:)
      )
    end

    def parent_split_payload(child:, child_occurrence:)
      {
        child_task_id: child.id,
        end_reason: end_reason,
        responsible_id: child.responsible_id,
        source_planned_occurrence_id: source_planned_occurrence&.id,
        planned_occurrence_id: child_occurrence&.id,
        planned_occurrence_scheduled_at: child_occurrence&.scheduled_at
      }
    end

    def child_created_payload(child_occurrence:)
      {
        parent_task_id: task.id,
        end_reason: end_reason,
        source_planned_occurrence_id: source_planned_occurrence&.id,
        planned_occurrence_id: child_occurrence&.id,
        planned_occurrence_scheduled_at: child_occurrence&.scheduled_at
      }
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
        next_run_at: nil,
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
