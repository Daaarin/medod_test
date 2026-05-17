class SyncRecurringTaskEndDates < ActiveRecord::Migration[8.0]
  def up
    say_with_time "Backfilling recurring task end dates" do
      execute <<~SQL.squish
        UPDATE tasks
        SET completion_date = recurrence_rules.date_end
        FROM recurrence_rules
        WHERE tasks.id = recurrence_rules.task_id
          AND tasks.task_kind = 'recurring'
          AND tasks.completion_date IS NULL
          AND recurrence_rules.date_end IS NOT NULL
      SQL

      execute <<~SQL.squish
        UPDATE recurrence_rules
        SET date_end = tasks.completion_date
        FROM tasks
        WHERE recurrence_rules.task_id = tasks.id
          AND tasks.task_kind = 'recurring'
          AND tasks.completion_date IS NOT NULL
          AND recurrence_rules.date_end IS NULL
      SQL
    end
  end

  def down
    # No safe rollback without losing user-facing end dates.
  end
end
