module Api
  module V1
    class UsersController < ApplicationController
      before_action :authenticate_user!
      before_action :authorize_admin!

      def index
        users = User.order(role: :asc, last_name: :asc, name: :asc, id: :asc)

        render json: { data: users.map { |user| user_payload(user) } }, status: :ok
      end

      private

        def authorize_admin!
          return if current_user.administrator?

          render json: { error: "Forbidden" }, status: :forbidden
        end

        def user_payload(user)
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
