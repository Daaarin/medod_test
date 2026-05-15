# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

[
  "Отчётность",
  "Операции",
  "Звонок"
].each do |name|
  tag = Tag.find_or_initialize_by(name: name)
  next if tag.is_system_tag?

  tag.is_system_tag = true
  tag.deactivated_at = nil
  tag.save!
end
