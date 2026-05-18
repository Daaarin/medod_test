module Tasks
  class PostponeOccurrence
    class << self
      def call(occurrence:, postpone_to:, actor_id:)
        new(occurrence:, postpone_to:, actor_id:).call
      end
    end

    def initialize(occurrence:, postpone_to:, actor_id:)
      @occurrence = occurrence
      @postpone_to = postpone_to
      @actor_id = actor_id
    end

    def call
      Task.transaction do
        occurrence.task.with_lock do
          occurrence.lock!
          raise ArgumentError, "occurrence must be planned or postponed on an active task" unless occurrence.current? && occurrence.task.active?
          raise ArgumentError, "postpone_to must be on or after the current occurrence time" if postpone_to.blank? || postpone_to < occurrence.actionable_time

          previous_next_run_at = occurrence.task.next_run_at
          occurrence.update!(
            status: :postponed,
            postponed_to: postpone_to
          )

          occurrence.task.update!(next_run_at: postpone_to)

          Tasks::AppendEvent.call(
            task: occurrence.task,
            occurrence: occurrence,
            event_type: :postponed,
            actor_id: actor_id,
            payload: {
              scheduled_at: occurrence.scheduled_at,
              previous_next_run_at: previous_next_run_at,
              postponed_to: postpone_to
            }
          )

          occurrence
        end
      end
    end

    private

      attr_reader :occurrence, :postpone_to, :actor_id
  end
end
