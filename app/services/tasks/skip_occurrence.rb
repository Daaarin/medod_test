module Tasks
  class SkipOccurrence
    class << self
      def call(occurrence:, skip_reason:, actor_id:)
        new(occurrence:, skip_reason:, actor_id:).call
      end
    end

    def initialize(occurrence:, skip_reason:, actor_id:)
      @occurrence = occurrence
      @skip_reason = skip_reason
      @actor_id = actor_id
    end

    def call
      Task.transaction do
        task.with_lock do
          occurrence.lock!
          raise ArgumentError, "occurrence must be planned or postponed on an active task" unless occurrence.current? && task.active?

          skipped_at = Time.current
          occurrence.update!(
            status: :skipped,
            skip_reason: resolved_skip_reason
          )

          Tasks::AppendEvent.call(
            task: task,
            occurrence: occurrence,
            event_type: :skipped,
            actor_id: actor_id,
            payload: {
              scheduled_at: occurrence.scheduled_at,
              actual_at: skipped_at,
              skip_reason: occurrence.skip_reason
            }
          )

          advance_series!(skipped_at)

          occurrence
        end
      end
    end

    private

      attr_reader :occurrence, :skip_reason, :actor_id

      def task
        occurrence.task
      end

      def advance_series!(skipped_at)
        if task.one_time?
          task.update!(
            status: :completed,
            end_reason: :series_completed,
            completed_at: skipped_at,
            next_run_at: nil
          )

          Tasks::AppendEvent.call(
            task: task,
            occurrence: occurrence,
            event_type: :completed,
            actor_id: actor_id,
            payload: { end_reason: :series_completed }
          )
          return
        end

        next_run_at = next_occurrence_after(skipped_at)

        if next_run_at.nil?
          task.update!(next_run_at: nil)
        else
          task.task_occurrences.create!(
            scheduled_at: next_run_at,
            status: :planned,
            generated_at: skipped_at
          )

          task.update!(next_run_at: next_run_at)
        end
      end

      def next_occurrence_after(skipped_at)
        cursor = [ skipped_at, occurrence.actionable_time ].compact.max + 1.second
        TaskScheduling::NextOccurrenceCalculator.call(task: task, from_time: cursor)
      end

      def resolved_skip_reason
        skip_reason.presence || "skipped"
      end
  end
end
