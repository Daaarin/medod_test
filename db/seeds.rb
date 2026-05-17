# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
require_relative "seeds/medods_demo_data"

%w[Отчётность Операции Звонок].each do |name|
  tag = Tag.find_or_initialize_by(name: name)

  if tag.new_record?
    tag.is_system_tag = true
    tag.deactivated_at = nil
    tag.save!
  elsif !tag.system_tag?
    tag.update!(is_system_tag: true, deactivated_at: nil)
  end
end

unless Rails.env.production?
  MedodsDemoData::Runner.call
end
