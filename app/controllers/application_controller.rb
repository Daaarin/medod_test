class ApplicationController < ActionController::API
  def authenticate_user!
    return if current_user

    render json: { error: "Unauthorized" }, status: :unauthorized
  end

  def current_user
    @current_user ||= User.authenticate_token(bearer_token)
  end

  private

    def bearer_token
      authorization = request.headers["Authorization"].to_s
      scheme, token = authorization.split(" ", 2)
      return token if scheme&.casecmp("Bearer")&.zero?

      nil
    end
end
