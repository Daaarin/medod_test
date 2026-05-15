class CreateRecurrenceRules < ActiveRecord::Migration[8.0]
  def change
    create_table :recurrence_rules do |t|
      t.references :task, null: false, foreign_key: true, index: { unique: true }
      t.string :rule_type, null: false
      t.integer :interval_value
      t.integer :day_of_month
      t.string :day_of_month_parity
      t.integer :month_of_year
      t.integer :weekday
      t.string :weekday_parity
      t.time :execution_time, null: false
      t.string :timezone, null: false
      t.date :date_start, null: false
      t.date :date_end

      t.timestamps null: false
    end

    add_index :recurrence_rules, :rule_type
  end
end
