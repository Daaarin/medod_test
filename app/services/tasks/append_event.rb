module Tasks
  class AppendEvent
    class << self
      def call(task:, event_type:, actor_id:, occurrence: nil, payload: {})
        new(task:, event_type:, actor_id:, occurrence:, payload:).call
      end
    end

    def initialize(task:, event_type:, actor_id:, occurrence:, payload:)
      @task = task
      @event_type = event_type
      @actor_id = actor_id
      @occurrence = occurrence
      @payload = payload || {}
    end

    def call
      TaskEvent.create!(
        task: task,
        occurrence: occurrence,
        event_type: event_type,
        actor_id: actor_id,
        occurred_at: Time.current,
        payload_json: payload
      )
    end

    private

    attr_reader :task, :event_type, :actor_id, :occurrence, :payload
  end
end
