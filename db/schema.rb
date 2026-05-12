# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_05_12_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "recurrence_rules", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.string "rule_type", null: false
    t.integer "interval_value"
    t.integer "day_of_month"
    t.string "day_of_month_parity"
    t.integer "month_of_year"
    t.integer "weekday"
    t.string "weekday_parity"
    t.time "execution_time", null: false
    t.string "timezone", null: false
    t.date "date_start", null: false
    t.date "date_end"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rule_type"], name: "index_recurrence_rules_on_rule_type"
    t.index ["task_id"], name: "index_recurrence_rules_on_task_id", unique: true
  end

  create_table "task_events", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.bigint "occurrence_id"
    t.string "event_type", null: false
    t.bigint "actor_id", null: false
    t.datetime "occurred_at", null: false
    t.jsonb "payload_json", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_task_events_on_actor_id"
    t.index ["event_type"], name: "index_task_events_on_event_type"
    t.index ["occurred_at"], name: "index_task_events_on_occurred_at"
    t.index ["occurrence_id"], name: "index_task_events_on_occurrence_id"
    t.index ["task_id"], name: "index_task_events_on_task_id"
  end

  create_table "task_occurrences", force: :cascade do |t|
    t.bigint "task_id", null: false
    t.datetime "scheduled_at", null: false
    t.string "status", null: false
    t.datetime "actual_at"
    t.datetime "postponed_to"
    t.string "skip_reason"
    t.datetime "generated_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["task_id", "status"], name: "index_task_occurrences_on_task_id_and_status"
    t.index ["task_id"], name: "index_task_occurrences_on_task_id"
    t.index ["task_id"], name: "index_task_occurrences_on_task_id_when_planned", unique: true, where: "((status)::text = 'planned'::text)"
  end

  create_table "tasks", force: :cascade do |t|
    t.bigint "parent_task_id"
    t.bigint "root_task_id"
    t.string "task_kind", null: false
    t.string "status", null: false
    t.string "end_reason"
    t.string "title", null: false
    t.text "description"
    t.bigint "responsible_id", null: false
    t.datetime "first_run_at"
    t.datetime "next_run_at"
    t.datetime "completed_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["next_run_at"], name: "index_tasks_on_next_run_at"
    t.index ["parent_task_id"], name: "index_tasks_on_parent_task_id"
    t.index ["responsible_id"], name: "index_tasks_on_responsible_id"
    t.index ["root_task_id"], name: "index_tasks_on_root_task_id"
    t.index ["status"], name: "index_tasks_on_status"
    t.index ["task_kind"], name: "index_tasks_on_task_kind"
  end

  add_foreign_key "recurrence_rules", "tasks"
  add_foreign_key "task_events", "task_occurrences", column: "occurrence_id"
  add_foreign_key "task_events", "tasks"
  add_foreign_key "task_occurrences", "tasks"
  add_foreign_key "tasks", "tasks", column: "parent_task_id"
  add_foreign_key "tasks", "tasks", column: "root_task_id"
end
