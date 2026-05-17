module Api
  module V1
    class TaskPayloadPresenter
      def self.render(task)
        new(task).render
      end

      def initialize(task)
        @task = task
      end

      def render
        {
          id: task.id.to_s,
          type: "task",
          attributes: task_attributes
        }
      end

      private

        attr_reader :task

        def task_attributes
          {
            name: task.name,
            description: task.description,
            completion_date: task.completion_date&.iso8601,
            status: task.status,
            task_kind: task.task_kind,
            creator_id: task.creator_id,
            responsible_id: task.responsible_id,
            delegated_user_id: task.delegated_user_id,
            creator: user_payload(task.creator),
            responsible: user_payload(task.responsible),
            delegated_user: user_payload(task.delegated_user),
            first_run_at: task.first_run_at&.iso8601,
            next_run_at: task.next_run_at&.iso8601,
            accepted_at: task.accepted_at&.iso8601,
            completed_at: task.completed_at&.iso8601,
            cancelled_at: task.cancelled_at&.iso8601,
            cancellation_reason: task.cancellation_reason,
            end_reason: task.end_reason,
            deactivated_at: task.deactivated_at&.iso8601,
            tags: task_tags
          }
        end

        def task_tags
          task_tags_source
              .select { |task_tag| task_tag.active? && task_tag.tag&.active? }
              .sort_by { |task_tag| [ task_tag.created_at || Time.zone.at(0), task_tag.id || 0 ] }
              .map { |task_tag| tag_payload(task_tag.tag) }
        end

        def task_tags_source
          return task.task_tags if task.association(:task_tags).loaded?

          task.task_tags.includes(:tag)
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

        def user_payload(user)
          return nil unless user

          {
            id: user.id,
            type: "user",
            attributes: {
              email: user.email,
              role: user.role,
              name: user.name,
              last_name: user.last_name,
              display_name: user.display_name
            }
          }
        end
    end
  end
end
