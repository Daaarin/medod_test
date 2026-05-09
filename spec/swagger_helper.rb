require_relative "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s
  config.openapi_specs = {
    "v1/swagger.json" => {
      openapi: "3.0.1",
      info: {
        title: "Medods Test API",
        version: "v1"
      },
      servers: [
        {
          url: "http://localhost:3000",
          description: "Rails API"
        }
      ],
      paths: {},
      components: {
        securitySchemes: {}
      }
    }
  }
  config.openapi_format = :json
end
