require "rails_helper"
require Rails.root.join("db", "migrate", "20260514000003_update_tasks_for_public_api")

RSpec.describe UpdateTasksForPublicApi, type: :migration do
  it "backfills responsible_id from creator before rollback without deleting tasks" do
    creator = User.create!(
      email: "creator@example.test",
      password: "password123",
      role: :administrator,
      name: "Anna",
      last_name: "Admin"
    )
    task = Task.create!(
      task_kind: :one_time,
      status: :draft,
      name: "Draft task",
      creator: creator
    )

    expect(task.responsible_id).to be_nil

    expect do
      described_class.new.send(:backfill_responsible_ids_for_rollback!)
    end.not_to change { Task.where(id: task.id).count }

    expect(task.reload.responsible_id).to eq(creator.id)
  end

  it "creates non-guessable placeholder users for legacy responsible ids" do
    migration = described_class.new
    legacy_ids = [ 90_001, 90_002 ]
    connection = Task.connection

    connection.remove_foreign_key :tasks, column: :responsible_id

    legacy_ids.each do |legacy_id|
      connection.execute(<<~SQL.squish)
        INSERT INTO tasks (
          task_kind,
          status,
          name,
          responsible_id,
          created_at,
          updated_at
        ) VALUES (
          'one_time',
          'draft',
          'Legacy task #{legacy_id}',
          #{legacy_id},
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        )
      SQL
    end

    migration.send(:create_placeholder_users_for_legacy_responsible_ids)

    placeholders = User.where(id: legacy_ids).order(:id)
    expect(placeholders.map(&:email)).to eq(
      legacy_ids.map { |legacy_id| "legacy-task-owner-#{legacy_id}@example.invalid" }
    )
    expect(placeholders.map(&:password_salt).uniq.size).to eq(2)
    expect(placeholders.map(&:password_digest).uniq.size).to eq(2)
    placeholders.each do |placeholder|
      expect(placeholder.authenticate("legacy-task-placeholder")).to be(false)
    end
  ensure
    connection.add_foreign_key :tasks, :users, column: :responsible_id unless connection.foreign_key_exists?(:tasks, :users, column: :responsible_id)
  end
end
