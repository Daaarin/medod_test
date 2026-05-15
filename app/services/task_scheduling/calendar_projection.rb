module TaskScheduling
  class CalendarProjection
    class << self
      def call(task:, range_start:, range_end:)
        new(task:, range_start:, range_end:).call
      end
    end

    def initialize(task:, range_start:, range_end:)
      @task = task
      @range_start = range_start
      @range_end = range_end
    end

    def call
      return [] if range_end < range_start

      if task.one_time?
        projected_one_time_occurrence
      else
        projected_recurrence
      end
    end

    private

      attr_reader :task, :range_start, :range_end

      def projected_one_time_occurrence
        scheduled_time = task.next_run_at || task.first_run_at
        return [] unless scheduled_time
        return [] unless within_range?(scheduled_time, range_start, range_end)

        [ scheduled_time ]
      end

      def projected_recurrence
        zone = recurrence_zone
        return [] unless zone

        current_times = persisted_current_occurrence_times
        projected = current_times.select { |time| within_range?(time, range_start, range_end) }
        cursor = recurrence_cursor(zone, current_times)
        range_end_in_zone = range_end.in_time_zone(zone)

        loop do
          occurrence = TaskScheduling::NextOccurrenceCalculator.call(task: task, from_time: cursor)
          break unless occurrence
          break if occurrence > range_end_in_zone

          projected << occurrence
          cursor = occurrence + 1.second
        end

        projected
      end

      def persisted_current_occurrence_times
        task.task_occurrences
          .where(status: [ :planned, :postponed ])
          .order(:scheduled_at, :id)
          .filter_map { |occurrence| actionable_time(occurrence) }
      end

      def actionable_time(occurrence)
        return occurrence.postponed_to || occurrence.scheduled_at if occurrence.postponed?

        occurrence.scheduled_at
      end

      def recurrence_cursor(zone, current_times)
        boundary = current_times.max
        cursor = boundary ? [ range_start, boundary + 1.second ].max : range_start
        cursor.in_time_zone(zone)
      end

      def recurrence_zone
        rule = task.recurrence_rule
        return nil unless rule

        ActiveSupport::TimeZone[rule.timezone]
      end

      def within_range?(time, start_time, end_time)
        time >= start_time && time <= end_time
      end
  end
end
