class EnforceOneCurrentTaskOccurrence < ActiveRecord::Migration[8.0]
  def up
    remove_index :task_occurrences, name: "index_task_occurrences_on_task_id_when_planned"
    add_index :task_occurrences,
      :task_id,
      unique: true,
      where: "status IN ('planned', 'postponed')",
      name: "index_task_occurrences_on_task_id_when_current"
  end

  def down
    remove_index :task_occurrences, name: "index_task_occurrences_on_task_id_when_current"
    add_index :task_occurrences,
      :task_id,
      unique: true,
      where: "status = 'planned'",
      name: "index_task_occurrences_on_task_id_when_planned"
  end
end
