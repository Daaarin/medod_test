class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :is_system_tag, null: false, default: false
      t.datetime :deactivated_at

      t.timestamps
    end
  end
end
