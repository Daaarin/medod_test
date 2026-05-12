class CreateTaskEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :task_events do |t|
      t.references :task, null: false, foreign_key: true
      t.references :occurrence, null: true, foreign_key: { to_table: :task_occurrences }
      t.string :event_type, null: false
      t.bigint :actor_id, null: false
      t.datetime :occurred_at, null: false
      t.jsonb :payload_json, null: false, default: {}

      t.timestamps null: false
    end

    add_index :task_events, :event_type
    add_index :task_events, :actor_id
    add_index :task_events, :occurred_at
  end
end
