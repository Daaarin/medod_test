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

          child_occurrence = reconcile_current_occurrence!(child)
          append_audit_events!(child, child_occurrence)

          finalize_parent!

          child
        end
      end
    end

    private

      attr_reader :task, :end_reason, :responsible_id, :recurrence_rule_attributes, :actor_id, :source_current_occurrence_snapshot

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

      def reconcile_current_occurrence!(child)
        current_occurrence = lock_parent_current_occurrence
        @source_current_occurrence_snapshot = occurrence_snapshot(current_occurrence)

        if end_reason.to_s == "schedule_changed"
          supersede_source_current_occurrence!(current_occurrence)
          return create_child_planned_occurrence!(child)
        end

        clone_current_occurrence_to_child!(child, current_occurrence)
      end

      def clone_current_occurrence_to_child!(child, current_occurrence)
        return create_child_planned_occurrence!(child) unless current_occurrence

        child_occurrence = child.task_occurrences.create!(
          scheduled_at: current_occurrence.scheduled_at,
          status: current_occurrence.status,
          actual_at: current_occurrence.actual_at,
          postponed_to: current_occurrence.postponed_to,
          skip_reason: current_occurrence.skip_reason,
          generated_at: Time.current
        )

        child.update!(
          next_run_at: child_occurrence.postponed_to || child_occurrence.scheduled_at
        )
        supersede_source_current_occurrence!(current_occurrence)
        child_occurrence
      end

      def supersede_source_current_occurrence!(current_occurrence)
        return unless current_occurrence

        current_occurrence.update!(status: :superseded)
      end

      def create_child_planned_occurrence!(child)
        occurrence_time = next_child_occurrence_time(child)
        return clear_child_next_run_at!(child) unless occurrence_time

        child.task_occurrences.create!(
          scheduled_at: occurrence_time,
          status: :planned,
          generated_at: Time.current
        ).tap do |occurrence|
          child.update!(next_run_at: occurrence.scheduled_at)
        end
      end

      def clear_child_next_run_at!(child)
        child.update!(next_run_at: nil)
        nil
      end

      def next_child_occurrence_time(child)
        TaskScheduling::NextOccurrenceCalculator.call(task: child, from_time: Time.current)
      end

      def lock_parent_current_occurrence
        current_occurrences = task.task_occurrences.where(status: [ :planned, :postponed ]).lock.order(:created_at, :id).to_a
        return current_occurrences.first if current_occurrences.size <= 1

        raise ArgumentError, "task has multiple current occurrences"
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
          payload: child_created_payload(child:, child_occurrence:)
        )
      end

      def parent_split_payload(child:, child_occurrence:)
        source_current_occurrence_payload.merge(
          child_task_id: child.id,
          end_reason: end_reason,
          responsible_id: child.responsible_id,
          child_occurrence_id: child_occurrence&.id,
          child_occurrence_status: child_occurrence&.status,
          child_occurrence_scheduled_at: child_occurrence&.scheduled_at,
          child_next_run_at: child&.next_run_at
        )
      end

      def child_created_payload(child:, child_occurrence:)
        source_current_occurrence_payload.merge(
          child_task_id: child.id,
          parent_task_id: task.id,
          end_reason: end_reason,
          responsible_id: child.responsible_id,
          child_occurrence_id: child_occurrence&.id,
          child_occurrence_status: child_occurrence&.status,
          child_occurrence_scheduled_at: child_occurrence&.scheduled_at,
          child_next_run_at: child.next_run_at
        )
      end

      def source_current_occurrence_payload
        return {} unless source_current_occurrence_snapshot

        {
          source_current_occurrence_id: source_current_occurrence_snapshot[:id],
          source_current_occurrence_status: source_current_occurrence_snapshot[:status],
          source_current_occurrence_scheduled_at: source_current_occurrence_snapshot[:scheduled_at],
          source_current_occurrence_postponed_to: source_current_occurrence_snapshot[:postponed_to]
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

      def occurrence_snapshot(occurrence)
        return nil unless occurrence

        {
          id: occurrence.id,
          status: occurrence.status,
          scheduled_at: occurrence.scheduled_at,
          postponed_to: occurrence.postponed_to
        }
      end
  end
end
