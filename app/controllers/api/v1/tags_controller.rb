module Api
  module V1
    class TagsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_tag, only: %i[update destroy]

      def index
        tags = tag_scope.order(created_at: :asc, id: :asc)

        render json: { data: tags.map { |tag| tag_payload(tag) } }, status: :ok
      end

      def create
        tag = Tag.new(tag_params)

        if tag.save
          render json: { data: tag_payload(tag) }, status: :created
        else
          render_unprocessable_entity(tag)
        end
      end

      def update
        if @tag.update(tag_params)
          render json: { data: tag_payload(@tag) }, status: :ok
        else
          render_unprocessable_entity(@tag)
        end
      end

      def destroy
        if @tag.deactivate
          head :no_content
        else
          render_unprocessable_entity(@tag)
        end
      end

      private

        def set_tag
          @tag = tag_scope.find(params[:id])
        end

        def tag_scope
          return Tag.all if include_deactivated?

          Tag.active
        end

        def include_deactivated?
          ActiveModel::Type::Boolean.new.cast(params[:include_deactivated])
        end

        def tag_params
          params.fetch(:tag, {}).permit(:name, :description)
        end

        def render_unprocessable_entity(tag)
          render json: { errors: tag.errors.full_messages }, status: :unprocessable_entity
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
