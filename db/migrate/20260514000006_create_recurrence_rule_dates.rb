class CreateRecurrenceRuleDates < ActiveRecord::Migration[8.0]
  def change
    create_table :recurrence_rule_dates do |t|
      t.references :recurrence_rule, null: false, foreign_key: true
      t.date :run_date, null: false

      t.timestamps null: false
    end

    add_index :recurrence_rule_dates, [ :recurrence_rule_id, :run_date ], unique: true, name: "index_recurrence_rule_dates_on_rule_and_run_date"
  end
end
