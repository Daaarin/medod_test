require "swagger_helper"

RSpec.describe "Health API", type: :request do
  before do
    host! "localhost"
  end

  path "/up" do
    get "Health check" do
      tags "Health"
      produces "text/plain"

      response "200", "healthy" do
        run_test!
      end
    end
  end
end
