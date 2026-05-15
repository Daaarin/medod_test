module Api
  module V1
    class TaskOccurrencesController < ApplicationController
      rescue_from ActionController::BadRequest, with: :render_bad_request

      before_action :authenticate_user!
      before_action :set_occurrence
      before_action :authorize_task_write!

      def postpone
        Tasks::PostponeOccurrence.call(
          occurrence: @occurrence,
          postpone_to: postponed_to_param,
          actor_id: current_user.id
        )

        render_transition_payload
      rescue ArgumentError => e
        render_unprocessable_entity([ e.message ])
      end

      def execute
        Tasks::AdvanceOccurrence.call(
          occurrence: @occurrence,
          actor_id: current_user.id
        )

        render_transition_payload
      rescue ArgumentError => e
        render_unprocessable_entity([ e.message ])
      end

      def skip
        Tasks::SkipOccurrence.call(
          occurrence: @occurrence,
          skip_reason: params[:skip_reason],
          actor_id: current_user.id
        )

        render_transition_payload
      rescue ArgumentError => e
        render_unprocessable_entity([ e.message ])
      end

      private

        def set_occurrence
          @occurrence = visible_task_occurrences.find(params[:id])
          @task = @occurrence.task
        end

        def authorize_task_write!
          return if current_user.administrator?
          return if @task.creator_id == current_user.id
          return if @task.responsible_id == current_user.id

          render json: { error: "Forbidden" }, status: :forbidden
        end

        def visible_task_occurrences
          TaskOccurrence.joins(:task).merge(visible_tasks).distinct
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

        def postponed_to_param
          value = params[:postponed_to]
          raise ActionController::BadRequest, "postponed_to must be ISO 8601" if value.blank?

          Time.zone.iso8601(value.to_s)
        rescue ArgumentError, TypeError
          raise ActionController::BadRequest, "postponed_to must be ISO 8601"
        end

        def render_transition_payload
          render json: { data: { occurrence: occurrence_payload(@occurrence.reload), task: task_payload(@task.reload) } }, status: :ok
        end

        def render_unprocessable_entity(errors)
          render json: { errors: Array(errors).flatten.compact }, status: :unprocessable_entity
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

        def occurrence_payload(occurrence)
          {
            id: occurrence.id.to_s,
            type: "task_occurrence",
            attributes: {
              scheduled_at: occurrence.scheduled_at&.iso8601,
              status: occurrence.status,
              actual_at: occurrence.actual_at&.iso8601,
              postponed_to: occurrence.postponed_to&.iso8601,
              skip_reason: occurrence.skip_reason,
              generated_at: occurrence.generated_at&.iso8601
            }
          }
        end
    end
  end
end
