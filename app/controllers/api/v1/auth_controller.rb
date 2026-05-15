module Api
  module V1
    class AuthController < ApplicationController
      before_action :authenticate_user!, only: :show

      def create
        user = User.find_by(email: params[:email].to_s.strip.downcase)

        if user&.authenticate(params[:password])
          render json: { token: user.issue_auth_token!, user: user_payload(user) }, status: :ok
        else
          render json: { error: "Invalid email or password" }, status: :unauthorized
        end
      end

      def show
        render json: { user: user_payload(current_user) }, status: :ok
      end

      private

        def user_payload(user)
          {
            id: user.id,
            email: user.email,
            role: user.role,
            name: user.name,
            last_name: user.last_name
          }
        end
    end
  end
end
