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

      def register
        unless User::SIGNUP_ROLES.include?(register_params[:role].to_s)
          render json: { errors: [ "Role is not allowed" ] }, status: :unprocessable_entity
          return
        end

        user = User.new(register_params.except(:password))
        user.password = register_params[:password]

        if user.save
          render json: { token: user.issue_auth_token!, user: user_payload(user) }, status: :created
        else
          render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def show
        render json: { user: user_payload(current_user) }, status: :ok
      end

      private

        def register_params
          params.permit(:email, :password, :name, :last_name).tap do |whitelisted|
            whitelisted[:role] = params[:role] unless params[:role] == "admin"
          end
        end

        def user_payload(user)
          {
            id: user.id,
            email: user.email,
            role: user.role,
            name: user.name,
            last_name: user.last_name,
            display_name: user.display_name
          }
        end
    end
  end
end
