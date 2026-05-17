Rack::Attack.cache.store = if Rails.env.test?
  ActiveSupport::Cache::MemoryStore.new
else
  Rails.cache
end

class Rack::Attack
  throttle("auth/login/ip+email", limit: 5, period: 5.minutes) do |request|
    next unless request.post? && request.path == "/api/v1/auth/login"

    normalized_email = normalized_login_email(request)
    next if normalized_email.blank?

    "#{request.ip}:#{normalized_email}"
  end

  self.throttled_responder = lambda do |_request|
    [
      429,
      { "Content-Type" => "application/json" },
      [ { error: "Too many login attempts" }.to_json ]
    ]
  end

  def self.normalized_login_email(request)
    normalized_email = request.params["email"].to_s.strip.downcase
    return normalized_email if normalized_email.present?

    json_login_email(request)
  end

  def self.json_login_email(request)
    return unless request.media_type == "application/json"

    input = request.env["rack.input"]
    return unless input

    body = input.read
    input.rewind

    JSON.parse(body).fetch("email", nil).to_s.strip.downcase
  rescue JSON::ParserError
    nil
  end
end
