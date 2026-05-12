class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.references :parent_task, null: true, foreign_key: { to_table: :tasks }
      t.references :root_task, null: true, foreign_key: { to_table: :tasks }
      t.string :task_kind, null: false
      t.string :status, null: false
      t.string :end_reason
      t.string :title, null: false
      t.text :description
      t.bigint :responsible_id, null: false
      t.datetime :first_run_at
      t.datetime :next_run_at
      t.datetime :completed_at
      t.datetime :cancelled_at

      t.timestamps null: false
    end

    add_index :tasks, :responsible_id
    add_index :tasks, :status
    add_index :tasks, :task_kind
    add_index :tasks, :next_run_at
  end
end
