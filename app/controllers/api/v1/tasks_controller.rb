module Api
  module V1
    class TasksController < ApplicationController
      rescue_from ActionController::BadRequest, with: :render_bad_request

      before_action :authenticate_user!
      before_action :set_task, only: %i[show update destroy]
      before_action :authorize_task_write!, only: %i[update destroy]

      def index
        tasks = filtered_tasks

        render json: { data: tasks.map { |task| task_payload(task) } }, status: :ok
      end

      def show
        render json: { data: task_payload(@task) }, status: :ok
      end

      def create
        return unless valid_task_date_params?(:create)

        task = Task.new(create_task_params)
        task.creator = current_user
        task.task_kind = "one_time" if task.task_kind.blank?
        task.status = "draft"
        task.responsible = current_user if assign_to_self?

        if valid_assignees?(task) && task.save
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
          @task = visible_tasks.find(params[:id])
        end

        def authorize_task_write!
          return if current_user.administrator?
          return if @task.creator_id == current_user.id
          return if @task.responsible_id == current_user.id

          render json: { error: "Forbidden" }, status: :forbidden
        end

        def filtered_tasks
          tasks = apply_scope(visible_tasks)
          tasks = apply_date_filters(tasks)

          tasks.order(created_at: :desc, id: :desc)
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

        def apply_date_filters(tasks)
          from_date = parse_date_param!(:from)
          to_date = parse_date_param!(:to)
          return tasks if from_date.blank? && to_date.blank?

          from_date ||= to_date
          to_date ||= from_date

          from_time = from_date.beginning_of_day
          to_time = to_date.end_of_day

          tasks.where(
            <<~SQL.squish,
              (completion_date BETWEEN :from_date AND :to_date)
              OR (first_run_at BETWEEN :from_time AND :to_time)
              OR (next_run_at BETWEEN :from_time AND :to_time)
            SQL
            from_date: from_date,
            to_date: to_date,
            from_time: from_time,
            to_time: to_time
          )
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
            :next_run_at
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

        def assignee_exists?(user_id)
          user_id.blank? || User.exists?(id: user_id)
        end

        def render_unprocessable_entity(task)
          render json: { errors: task.errors.full_messages }, status: :unprocessable_entity
        end

        def render_bad_request(error)
          render json: { error: error.message }, status: :bad_request
        end

        def task_payload(task)
          {
            id: task.id.to_s,
            type: "task",
            attributes: task_attributes(task)
          }
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
            deactivated_at: task.deactivated_at&.iso8601
          }
        end
    end
  end
end
