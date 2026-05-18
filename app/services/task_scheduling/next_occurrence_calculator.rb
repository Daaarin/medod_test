module TaskScheduling
  class NextOccurrenceCalculator
    class << self
      def call(task:, from_time:)
        new(task:, from_time:).call
      end
    end

    def initialize(task:, from_time:)
      @task = task
      @from_time = from_time
    end

    def call
      return next_one_time_occurrence if task.one_time?

      rule = task.recurrence_rule
      return nil unless rule

      zone = ActiveSupport::TimeZone[rule.timezone]
      return nil unless zone

      start_time = zoned_occurrence_time(zone, rule.date_start, rule.execution_time)
      search_time = [ from_time.in_time_zone(zone), start_time ].max

      case rule.rule_type
        when "every_n_days"
          next_every_n_days(rule, zone, search_time)
        when "every_n_months"
          next_every_n_months(rule, start_time, search_time)
        when "every_n_years"
          next_every_n_years(rule, start_time, search_time)
        when "day_of_month_parity"
          next_day_of_month_parity(rule, zone, search_time)
        when "weekday_parity"
          next_weekday_parity(rule, zone, search_time)
        when "specific_dates"
          next_specific_dates(rule, zone, search_time)
        else
          nil
      end
    end

    private

      attr_reader :task, :from_time

      def effective_date_end
        task.effective_recurrence_end_date
      end

      def next_one_time_occurrence
        scheduled_time = task.next_run_at || task.first_run_at
        return nil unless scheduled_time
        return nil if scheduled_time < from_time

        scheduled_time
      end

      def next_every_n_days(rule, zone, search_time)
        interval = positive_interval(rule.interval_value)
        return nil unless interval

        candidate_date = rule.date_start + aligned_day_offset(rule.date_start, search_time.to_date, interval)

        loop do
          candidate = zoned_occurrence_time(zone, candidate_date, rule.execution_time)
          return nil if past_date_end?(candidate, effective_date_end)
          return candidate if candidate >= search_time

          candidate_date += interval
        end
      end

      def next_every_n_months(rule, start_time, search_time)
        interval = positive_interval(rule.interval_value)
        return nil unless interval

        chosen_day = rule.day_of_month || rule.date_start.day
        period = [ 0, months_since_start(search_time.to_date, rule.date_start) / interval ].max

        loop do
          candidate = monthly_candidate(rule.date_start, chosen_day, period * interval, start_time.time_zone)
          return nil if past_date_end?(candidate, effective_date_end)
          return candidate if candidate >= search_time

          period += 1
        end
      end

      def next_every_n_years(rule, start_time, search_time)
        interval = positive_interval(rule.interval_value)
        return nil unless interval

        chosen_month = rule.month_of_year || rule.date_start.month
        chosen_day = rule.day_of_month || rule.date_start.day
        period = [ 0, years_since_start(search_time.to_date, rule.date_start) / interval ].max

        loop do
          candidate = yearly_candidate(rule.date_start.year + (period * interval), chosen_month, chosen_day, start_time.time_zone)
          return nil if past_date_end?(candidate, effective_date_end)
          return candidate if candidate >= search_time

          period += 1
        end
      end

      def next_day_of_month_parity(rule, zone, search_time)
        parity = rule.day_of_month_parity
        return nil unless parity

        candidate_date = search_time.to_date
        candidate_date = rule.date_start if candidate_date < rule.date_start

        loop do
          candidate = zoned_occurrence_time(zone, candidate_date, rule.execution_time)
          return nil if past_date_end?(candidate, effective_date_end)
          return candidate if parity_matches_day_of_month?(candidate_date, parity) && candidate >= search_time

          candidate_date += 1.day
        end
      end

      def next_weekday_parity(rule, zone, search_time)
        parity = rule.weekday_parity
        return nil unless parity

        candidate_date = search_time.to_date
        candidate_date = rule.date_start if candidate_date < rule.date_start

        loop do
          candidate = zoned_occurrence_time(zone, candidate_date, rule.execution_time)
          return nil if past_date_end?(candidate, effective_date_end)
          return candidate if parity_matches_weekday?(candidate_date, parity) && candidate >= search_time

          candidate_date += 1.day
        end
      end

      def next_specific_dates(rule, zone, search_time)
        specific_dates_for(rule).each do |recurrence_rule_date|
          next unless specific_date_within_window?(rule, recurrence_rule_date.run_date)

          candidate = zoned_occurrence_time(zone, recurrence_rule_date.run_date, rule.execution_time)
          return candidate if candidate >= search_time
        end

        nil
      end

      def zoned_occurrence_time(zone, date, execution_time)
        zone.local(
          date.year,
          date.month,
          date.day,
          execution_time.hour,
          execution_time.min,
          execution_time.sec,
          execution_time.usec
        )
      end

      def monthly_candidate(start_date, chosen_day, month_offset, zone)
        total_months = (start_date.year * 12) + (start_date.month - 1) + month_offset
        year = total_months / 12
        month = (total_months % 12) + 1
        day = clamped_day(year, month, chosen_day)
        zone.local(
          year,
          month,
          day,
          task.recurrence_rule.execution_time.hour,
          task.recurrence_rule.execution_time.min,
          task.recurrence_rule.execution_time.sec,
          task.recurrence_rule.execution_time.usec
        )
      end

      def yearly_candidate(year, month, chosen_day, zone)
        day = clamped_day(year, month, chosen_day)
        zone.local(
          year,
          month,
          day,
          task.recurrence_rule.execution_time.hour,
          task.recurrence_rule.execution_time.min,
          task.recurrence_rule.execution_time.sec,
          task.recurrence_rule.execution_time.usec
        )
      end

      def clamped_day(year, month, day)
        [ day, Date.new(year, month, -1).day ].min
      end

      def months_since_start(date, start_date)
        (date.year * 12 + date.month) - (start_date.year * 12 + start_date.month)
      end

      def years_since_start(date, start_date)
        date.year - start_date.year
      end

      def parity_matches_day_of_month?(date, parity)
        parity == "even" ? date.day.even? : date.day.odd?
      end

      def parity_matches_weekday?(date, parity)
        iso_weekday = date.cwday
        parity == "even" ? iso_weekday.even? : iso_weekday.odd?
      end

      def positive_interval(value)
        return nil if value.blank?

        value.positive? ? value : nil
      end

      def aligned_day_offset(start_date, search_date, interval)
        days_since_start = (search_date - start_date).to_i
        return 0 if days_since_start <= 0

        (days_since_start / interval) * interval
      end

      def past_date_end?(candidate, date_end)
        date_end.present? && candidate.to_date > date_end
      end

      def specific_date_within_window?(rule, run_date)
        return false if run_date < rule.date_start
        return false if effective_date_end.present? && run_date > effective_date_end

        true
      end

      def specific_dates_for(rule)
        rule.recurrence_rule_dates
          .to_a
          .sort_by do |recurrence_rule_date|
            [
              recurrence_rule_date.run_date,
              recurrence_rule_date.id || 0,
              recurrence_rule_date.object_id
            ]
          end
      end
  end
end
