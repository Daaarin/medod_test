module Api
  module V1
    class TasksController < ApplicationController
      rescue_from ActionController::BadRequest, with: :render_bad_request

      before_action :authenticate_user!
      before_action :set_task, only: %i[show update destroy]
      before_action :authorize_task_write!, only: %i[update destroy]

      def index
        tasks = filtered_tasks.to_a
        preload_date_filtered_occurrences!(tasks) if date_filter_requested?

        render json: { data: task_list_payloads(tasks) }, status: :ok
      end

      def show
        render json: { data: task_payload(@task) }, status: :ok
      end

      def create
        return unless valid_task_date_params?(:create)

        task = Task.new(create_task_params)
        task.creator = current_user
        task.task_kind = "one_time" if task.task_kind.blank?
        task.status = initial_status_for(task)
        task.responsible = current_user if assign_to_self?
        task.responsible = nil if task.delegated_user_id.present?

        if valid_assignees?(task) && valid_initial_occurrence_context?(task) && create_task_with_initial_occurrence(task)
          render json: { data: task_payload(task) }, status: :created
        else
          render_unprocessable_entity(task)
        end
      end

      def update
        return unless valid_task_date_params?(:update)

        if @task.update(update_task_params)
          render json: { data: task_payload(@task) }, status: :ok
        else
          render_unprocessable_entity(@task)
        end
      end

      def destroy
        if @task.final?
          render json: { errors: [ "Final tasks cannot be deactivated" ] }, status: :unprocessable_entity
        elsif @task.update(deactivated_at: Time.current)
          head :no_content
        else
          render_unprocessable_entity(@task)
        end
      end

      private

        def set_task
          @task = visible_tasks.includes(:recurrence_rule, :task_occurrences, task_tags: :tag).find(params[:id])
        end

        def authorize_task_write!
          return if current_user.administrator?
          return if @task.creator_id == current_user.id
          return if @task.responsible_id == current_user.id

          render json: { error: "Forbidden" }, status: :forbidden
        end

        def filtered_tasks
          tasks = apply_status_filter(apply_scope(visible_tasks))
          if date_filter_requested?
            tasks = date_filtered_task_candidates(tasks)
            return tasks.includes(:recurrence_rule, task_tags: :tag).order(created_at: :desc, id: :desc).distinct
          end

          tasks.includes(:recurrence_rule, :task_occurrences, task_tags: :tag).order(created_at: :desc, id: :desc)
        end

        def visible_tasks
          tasks = Task.where(deactivated_at: nil)

          unless current_user.administrator?
            tasks = tasks.where(
              "creator_id = :user_id OR responsible_id = :user_id OR delegated_user_id = :user_id",
              user_id: current_user.id
            )
          end

          tasks
        end

        def apply_scope(tasks)
          case params[:scope].to_s
            when "mine"
              tasks.where(responsible_id: current_user.id)
            when "delegated_to_me"
              tasks.where(delegated_user_id: current_user.id, status: "pending_acceptance")
            when "created_by_me"
              tasks.where(creator_id: current_user.id)
            else
              tasks
          end
        end

        def apply_status_filter(tasks)
          return tasks if status_filter.blank?

          tasks.where(status: status_filter)
        end

        def status_filter
          value = params[:status].presence
          return if value.blank?
          return value if Task.statuses.key?(value)

          raise ActionController::BadRequest, "status is not included in the list"
        end

        def date_filter_requested?
          params[:from].present? || params[:to].present?
        end

        def date_range
          from_date = parse_date_param!(:from)
          to_date = parse_date_param!(:to)
          return if from_date.blank? && to_date.blank?

          from_date ||= to_date
          to_date ||= from_date

          [ from_date.beginning_of_day, to_date.end_of_day ]
        end

        def date_filtered_task_candidates(tasks)
          range_start, range_end = date_range
          range_start_date = range_start.to_date
          range_end_date = range_end.to_date

          tasks.left_outer_joins(:recurrence_rule).where(
            <<~SQL.squish,
              EXISTS (
                SELECT 1
                FROM task_occurrences
                WHERE task_occurrences.task_id = tasks.id
                  AND (
                    task_occurrences.scheduled_at BETWEEN :range_start AND :range_end
                    OR task_occurrences.actual_at BETWEEN :range_start AND :range_end
                    OR task_occurrences.postponed_to BETWEEN :range_start AND :range_end
                  )
              )
              OR tasks.completion_date BETWEEN :range_start_date AND :range_end_date
              OR (
                recurrence_rules.id IS NOT NULL
                AND recurrence_rules.date_start <= :range_end_date
                AND (recurrence_rules.date_end IS NULL OR recurrence_rules.date_end >= :range_start_date)
              )
              OR (
                tasks.task_kind = 'one_time'
                AND (
                  tasks.first_run_at BETWEEN :range_start AND :range_end
                  OR tasks.next_run_at BETWEEN :range_start AND :range_end
                )
              )
              OR (
                tasks.task_kind = 'recurring'
                AND recurrence_rules.id IS NULL
                AND tasks.next_run_at BETWEEN :range_start AND :range_end
              )
            SQL
            range_start: range_start,
            range_end: range_end,
            range_start_date: range_start_date,
            range_end_date: range_end_date
          )
        end

        def preload_date_filtered_occurrences!(tasks)
          range_start, range_end = date_range
          occurrence_scope = TaskOccurrence.where(
            "(scheduled_at BETWEEN :range_start AND :range_end) OR (actual_at BETWEEN :range_start AND :range_end) OR (postponed_to BETWEEN :range_start AND :range_end)",
            range_start: range_start,
            range_end: range_end
          )

          ActiveRecord::Associations::Preloader.new(
            records: tasks,
            associations: :task_occurrences,
            scope: occurrence_scope
          ).call
        end

        def parse_date_param!(key)
          value = params[key]
          return if value.blank?

          Date.iso8601(value.to_s)
        rescue ArgumentError, TypeError
          raise ActionController::BadRequest, "#{key} must be an ISO 8601 date"
        end

        def create_task_params
          params.fetch(:task, {}).permit(
            :name,
            :description,
            :completion_date,
            :task_kind,
            :first_run_at,
            :next_run_at,
            :delegated_user_id,
            recurrence_rule_attributes: [
              :rule_type,
              :interval_value,
              :day_of_month,
              :day_of_month_parity,
              :month_of_year,
              :weekday,
              :weekday_parity,
              :execution_time,
              :timezone,
              :date_start,
              :date_end,
              { recurrence_rule_dates_attributes: [ :run_date ] }
            ]
          )
        end

        def update_task_params
          params.fetch(:task, {}).permit(
            :name,
            :description,
            :completion_date
          )
        end

        def assign_to_self?
          ActiveModel::Type::Boolean.new.cast(params.dig(:task, :assign_to_self))
        end

        def initial_status_for(task)
          return "pending_acceptance" if task.delegated_user_id.present?

          "draft"
        end

        def create_task_with_initial_occurrence(task)
          Task.transaction do
            task.save!
            schedule_initial_occurrence!(task)
          end

          true
        rescue ActiveRecord::RecordInvalid
          false
        end

        def schedule_initial_occurrence!(task)
          scheduled_at = task.next_run_at || initial_recurring_run_at(task)
          return if scheduled_at.blank?

          task.update!(next_run_at: scheduled_at) if task.next_run_at.blank?
          task.task_occurrences.create!(
            scheduled_at: scheduled_at,
            status: :planned,
            generated_at: Time.current
          )
        end

        def initial_recurring_run_at(task)
          return unless task.recurring?

          TaskScheduling::NextOccurrenceCalculator.call(
            task: task,
            from_time: task.first_run_at || task.recurrence_rule.date_start.beginning_of_day
          )
        end

        def valid_task_date_params?(action)
          allowed_keys = action == :create ? %i[completion_date first_run_at next_run_at] : %i[completion_date]

          allowed_keys.all? do |key|
            valid_task_date_param?(key)
          end
        end

        def valid_task_date_param?(key)
          value = params.dig(:task, key)
          return true if value.blank?

          parser = key == :completion_date ? Date.method(:iso8601) : Time.zone.method(:iso8601)
          parser.call(value.to_s)
          true
        rescue ArgumentError, TypeError
          render json: { error: "#{key} must be ISO 8601" }, status: :bad_request
          false
        end

        def valid_assignees?(task)
          return true if assignee_exists?(task.responsible_id) && assignee_exists?(task.delegated_user_id)

          task.errors.add(:base, "responsible_id and delegated_user_id must reference existing users")
          false
        end

        def valid_initial_occurrence_context?(task)
          return true unless task.recurring? && task.recurrence_rule.blank? && task.next_run_at.blank?

          task.errors.add(:base, "recurring tasks require recurrence_rule_attributes or next_run_at")
          false
        end

        def assignee_exists?(user_id)
          user_id.blank? || User.exists?(id: user_id)
        end

        def task_list_payloads(tasks)
          return tasks.map { |task| task_payload(task) } unless date_filter_requested?

          range_start, range_end = date_range
          tasks.flat_map { |task| date_filtered_payloads(task, range_start, range_end) }
        end

        def date_filtered_payloads(task, range_start, range_end)
          payloads = persisted_occurrence_payloads(task, range_start, range_end)
          payloads += projected_occurrence_payloads(task, range_start, range_end)
          payloads << task_payload(task) if payloads.empty? && completion_date_in_range?(task, range_start, range_end) && occurrence_status_filter.blank?

          payloads
        end

        def persisted_occurrence_payloads(task, range_start, range_end)
          task.task_occurrences.filter_map do |occurrence|
            occurrence_time = occurrence_filter_time(occurrence)
            next if occurrence_time.blank?
            next unless occurrence_time.between?(range_start, range_end)
            next unless occurrence_status_matches?(occurrence.status)

            task_payload(task, occurrence: occurrence, occurrence_time: occurrence_time)
          end
        end

        def projected_occurrence_payloads(task, range_start, range_end)
          return [] unless task.active?
          return [] unless occurrence_status_matches?("planned")

          projected_times(task, range_start, range_end).filter_map do |projected_time|
            next if persisted_occurrence_at?(task, projected_time)

            task_payload(task, projected_occurrence_time: projected_time)
          end
        end

        def projected_times(task, range_start, range_end)
          if task.one_time?
            scheduled_time = task.next_run_at || task.first_run_at
            return [ scheduled_time ].compact.select { |time| time.between?(range_start, range_end) }
          elsif task.recurring? && task.recurrence_rule.blank?
            scheduled_time = task.next_run_at
            return [ scheduled_time ].compact.select { |time| time.between?(range_start, range_end) }
          end

          TaskScheduling::CalendarProjection.call(task: task, range_start: range_start, range_end: range_end)
        end

        def persisted_occurrence_at?(task, projected_time)
          task.task_occurrences.any? do |occurrence|
            occurrence_filter_time(occurrence) == projected_time || occurrence.scheduled_at == projected_time
          end
        end

        def occurrence_filter_time(occurrence)
          return occurrence.postponed_to || occurrence.scheduled_at if occurrence.postponed?
          return occurrence.actual_at || occurrence.scheduled_at if occurrence.executed?

          occurrence.scheduled_at
        end

        def completion_date_in_range?(task, range_start, range_end)
          task.completion_date.present? && task.completion_date.between?(range_start.to_date, range_end.to_date)
        end

        def occurrence_status_filter
          params[:occurrence_status].presence
        end

        def occurrence_status_matches?(status)
          occurrence_status_filter.blank? || occurrence_status_filter == status
        end

        def render_unprocessable_entity(task)
          render json: { errors: task.errors.full_messages }, status: :unprocessable_entity
        end

        def render_bad_request(error)
          render json: { error: error.message }, status: :bad_request
        end

        def task_payload(task, occurrence: nil, occurrence_time: nil, projected_occurrence_time: nil)
          occurrence_data = occurrence_attributes(
            occurrence: occurrence,
            occurrence_time: occurrence_time,
            projected_occurrence_time: projected_occurrence_time
          )

          {
            id: occurrence_data ? "#{task.id}:#{occurrence_data.fetch(:scheduled_at)}" : task.id.to_s,
            type: "task",
            attributes: task_attributes(task).merge(occurrence_data ? { occurrence: occurrence_data } : {})
          }
        end

        def occurrence_attributes(occurrence:, occurrence_time:, projected_occurrence_time:)
          if occurrence
            {
              id: occurrence.id,
              scheduled_at: occurrence.scheduled_at&.iso8601,
              status: occurrence.status,
              actual_at: occurrence.actual_at&.iso8601,
              postponed_to: occurrence.postponed_to&.iso8601,
              skip_reason: occurrence.skip_reason,
              generated_at: occurrence.generated_at&.iso8601,
              projected: false,
              occurs_at: occurrence_time&.iso8601
            }
          elsif projected_occurrence_time
            {
              id: nil,
              scheduled_at: projected_occurrence_time.iso8601,
              status: "planned",
              actual_at: nil,
              postponed_to: nil,
              skip_reason: nil,
              generated_at: nil,
              projected: true,
              occurs_at: projected_occurrence_time.iso8601
            }
          end
        end

        def task_attributes(task)
          {
            name: task.name,
            description: task.description,
            completion_date: task.completion_date&.iso8601,
            status: task.status,
            task_kind: task.task_kind,
            creator_id: task.creator_id,
            responsible_id: task.responsible_id,
            delegated_user_id: task.delegated_user_id,
            first_run_at: task.first_run_at&.iso8601,
            next_run_at: task.next_run_at&.iso8601,
            accepted_at: task.accepted_at&.iso8601,
            completed_at: task.completed_at&.iso8601,
            cancelled_at: task.cancelled_at&.iso8601,
            cancellation_reason: task.cancellation_reason,
            end_reason: task.end_reason,
            deactivated_at: task.deactivated_at&.iso8601,
            tags: task_tags(task)
          }
        end

        def task_tags(task)
          task.task_tags
              .select { |task_tag| task_tag.active? && task_tag.tag&.active? }
              .sort_by { |task_tag| [ task_tag.created_at || Time.zone.at(0), task_tag.id || 0 ] }
              .map do |task_tag|
            tag_payload(task_tag.tag)
          end
        end

        def tag_payload(tag)
          {
            id: tag.id.to_s,
            type: "tag",
            attributes: {
              name: tag.name,
              description: tag.description,
              is_system_tag: tag.is_system_tag,
              deactivated_at: tag.deactivated_at&.iso8601
            }
          }
        end
    end
  end
end
