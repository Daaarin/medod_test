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
          raise ArgumentError, "occurrence must be planned on an active task" unless occurrence.planned? && occurrence.task.active?

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
            payload: { postponed_to: postpone_to }
          )

          occurrence
        end
      end
    end

    private

    attr_reader :occurrence, :postpone_to, :actor_id
  end
end
