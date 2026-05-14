ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "rswag/specs"
require_relative "spec_helper"

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  fixture_path = Rails.root.join("test", "fixtures").to_s
  if config.respond_to?(:fixture_paths=)
    config.fixture_paths = [ fixture_path ]
  else
    config.fixture_path = fixture_path
  end
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
