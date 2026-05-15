module Api
  module V1
    class TaskAcceptancesController < ApplicationController
      before_action :authenticate_user!
      before_action :set_task

      def accept
        result = with_acceptance_lock do
          transition_to_accepted!
        end

        render_transition_result(result)
      rescue ActiveRecord::RecordInvalid
        render_unprocessable_entity(@task.errors.full_messages)
      end

      def decline
        result = with_acceptance_lock do
          transition_to_declined!
        end

        render_transition_result(result)
      rescue ActiveRecord::RecordInvalid
        render_unprocessable_entity(@task.errors.full_messages)
      end

      private

        def set_task
          @task = visible_tasks.find(params[:task_id])
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

        def with_acceptance_lock
          result = nil

          @task.with_lock do
            @task.reload
            result = transition_blocker
            result ||= yield
          end

          result
        end

        def transition_blocker
          return :not_found if @task.deactivated_at.present?
          return :forbidden unless @task.delegated_user_id == current_user.id

          :not_pending_acceptance unless @task.pending_acceptance?
        end

        def transition_to_accepted!
          @task.update!(
            responsible: current_user,
            delegated_user: nil,
            status: :ongoing,
            accepted_at: Time.current
          )

          Tasks::AppendEvent.call(
            task: @task,
            event_type: :accepted,
            actor_id: current_user.id,
            payload: acceptance_payload
          )

          :ok
        end

        def transition_to_declined!
          @task.update!(
            status: :cancelled,
            end_reason: :declined,
            cancellation_reason: "was declined",
            cancelled_at: Time.current
          )

          Tasks::AppendEvent.call(
            task: @task,
            event_type: :cancelled,
            actor_id: current_user.id,
            payload: decline_payload
          )

          :ok
        end

        def render_transition_result(result)
          case result
            when :ok
              render json: { data: task_payload(@task.reload) }, status: :ok
            when :forbidden
              render json: { error: "Forbidden" }, status: :forbidden
            when :not_pending_acceptance
              render_unprocessable_entity([ "Task must be pending acceptance" ])
            when :not_found
              raise ActiveRecord::RecordNotFound
          end
        end

        def acceptance_payload
          {
            status: "ongoing",
            responsible_id: current_user.id,
            delegated_user_id: nil,
            accepted_at: @task.accepted_at&.iso8601
          }
        end

        def decline_payload
          {
            status: "cancelled",
            end_reason: "declined",
            cancellation_reason: "was declined",
            cancelled_at: @task.cancelled_at&.iso8601
          }
        end

        def render_unprocessable_entity(errors)
          render json: { errors: Array(errors).flatten.compact }, status: :unprocessable_entity
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
