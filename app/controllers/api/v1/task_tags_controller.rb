module Api
  module V1
    class TaskTagsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_task
      before_action :authorize_task_write!
      before_action :set_tag

      def create
        task_tag = TaskTag.attach!(task: @task, tag: @tag)

        render json: { data: tag_payload(task_tag.tag) }, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render_unprocessable_entity(e.record)
      end

      def destroy
        TaskTag.detach!(task: @task, tag: @tag)
        head :no_content
      rescue ActiveRecord::RecordNotFound
        raise
      rescue ActiveRecord::RecordInvalid => e
        render_unprocessable_entity(e.record)
      end

      private

        def set_task
          @task = visible_tasks.find(params[:task_id])
        end

        def set_tag
          @tag = params[:action] == "destroy" ? Tag.find(params[:tag_id]) : Tag.active.find(params[:tag_id])
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

        def authorize_task_write!
          return if current_user.administrator?
          return if @task.creator_id == current_user.id
          return if @task.responsible_id == current_user.id

          render json: { error: "Forbidden" }, status: :forbidden
        end

        def render_unprocessable_entity(record)
          render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
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
