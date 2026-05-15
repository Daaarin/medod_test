class CreateTaskOccurrences < ActiveRecord::Migration[8.0]
  def change
    create_table :task_occurrences do |t|
      t.references :task, null: false, foreign_key: true
      t.datetime :scheduled_at, null: false
      t.string :status, null: false
      t.datetime :actual_at
      t.datetime :postponed_to
      t.string :skip_reason
      t.datetime :generated_at

      t.timestamps null: false
    end

    add_index :task_occurrences, %i[task_id status]
    add_index :task_occurrences, :task_id, unique: true, where: "status = 'planned'", name: "index_task_occurrences_on_task_id_when_planned"
  end
end
