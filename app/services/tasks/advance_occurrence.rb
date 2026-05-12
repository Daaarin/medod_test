module Tasks
  class AdvanceOccurrence
    class << self
      def call(occurrence:, actor_id:)
        new(occurrence:, actor_id:).call
      end
    end

    def initialize(occurrence:, actor_id:)
      @occurrence = occurrence
      @actor_id = actor_id
    end

    def call
      Task.transaction do
        executed_at = Time.current
        occurrence.update!(
          status: :executed,
          actual_at: executed_at
        )

        Tasks::AppendEvent.call(
          task: task,
          occurrence: occurrence,
          event_type: :executed,
          actor_id: actor_id,
          payload: {
            scheduled_at: occurrence.scheduled_at,
            actual_at: executed_at
          }
        )

        if task.one_time?
          complete_lineage(occurrence:, executed_at:)
          return task
        end

        next_run_at = next_occurrence_after(executed_at)

        if next_run_at.nil?
          complete_lineage(occurrence:, executed_at:)
        else
          task.task_occurrences.create!(
            scheduled_at: next_run_at,
            status: :planned,
            generated_at: executed_at
          )

          task.update!(next_run_at: next_run_at)
        end

        task
      end
    end

    private

    attr_reader :occurrence, :actor_id

    def task
      occurrence.task
    end

    def next_occurrence_after(executed_at)
      cursor = [ executed_at, occurrence.scheduled_at ].compact.max + 1.second
      TaskScheduling::NextOccurrenceCalculator.call(task: task, from_time: cursor)
    end

    def complete_lineage(occurrence:, executed_at:)
      task.update_columns(
        status: Task.statuses.fetch("completed"),
        end_reason: Task.end_reasons.fetch("series_completed"),
        completed_at: executed_at,
        next_run_at: nil,
        updated_at: executed_at
      )

      Tasks::AppendEvent.call(
        task: task,
        occurrence: occurrence,
        event_type: :completed,
        actor_id: actor_id,
        payload: { end_reason: :series_completed }
      )
    end
  end
end
