allowed_origins = ENV.fetch("FRONTEND_ORIGINS", "http://localhost:5173,http://127.0.0.1:5173")
  .split(",")
  .map(&:strip)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: %w[Link],
      max_age: 600
  end
end
