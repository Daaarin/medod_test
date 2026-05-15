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
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer
          }
        },
        schemas: {
          error: {
            type: :object,
            properties: {
              error: { type: :string },
              errors: { type: :array, items: { type: :string } }
            }
          },
          task: {
            type: :object,
            properties: {
              id: { type: :string },
              type: { type: :string, enum: [ "task" ] },
              attributes: {
                type: :object,
                properties: {
                  name: { type: :string },
                  description: { type: :string, nullable: true },
                  status: { type: :string },
                  task_kind: { type: :string },
                  creator_id: { type: :integer, nullable: true },
                  responsible_id: { type: :integer, nullable: true },
                  delegated_user_id: { type: :integer, nullable: true },
                  completion_date: { type: :string, nullable: true },
                  deactivated_at: { type: :string, nullable: true }
                }
              }
            }
          },
          tag: {
            type: :object,
            properties: {
              id: { type: :string },
              type: { type: :string, enum: [ "tag" ] },
              attributes: {
                type: :object,
                properties: {
                  name: { type: :string },
                  description: { type: :string, nullable: true },
                  is_system_tag: { type: :boolean },
                  deactivated_at: { type: :string, nullable: true }
                }
              }
            }
          },
          task_occurrence: {
            type: :object,
            properties: {
              id: { type: :string },
              type: { type: :string, enum: [ "task_occurrence" ] },
              attributes: {
                type: :object,
                properties: {
                  scheduled_at: { type: :string },
                  status: { type: :string },
                  actual_at: { type: :string, nullable: true },
                  postponed_to: { type: :string, nullable: true },
                  skip_reason: { type: :string, nullable: true }
                }
              }
            }
          }
        }
      }
    }
  }
  config.openapi_format = :json
end
