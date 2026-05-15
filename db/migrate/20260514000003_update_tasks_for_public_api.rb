class UpdateTasksForPublicApi < ActiveRecord::Migration[8.0]
  PASSWORD_SALT_BYTES = 16
  PASSWORD_ITERATIONS = 120_000
  PASSWORD_DERIVED_KEY_LENGTH_BYTES = 32
  PASSWORD_DIGEST_ALGORITHM = "SHA256"

  def up
    rename_column :tasks, :title, :name

    add_column :tasks, :completion_date, :date
    add_column :tasks, :creator_id, :bigint
    add_column :tasks, :delegated_user_id, :bigint
    add_column :tasks, :accepted_at, :datetime
    add_column :tasks, :cancellation_reason, :string
    add_column :tasks, :deactivated_at, :datetime

    change_column_null :tasks, :responsible_id, true

    add_index :tasks, :creator_id
    add_index :tasks, :delegated_user_id

    create_placeholder_users_for_legacy_responsible_ids

    add_foreign_key :tasks, :users, column: :creator_id
    add_foreign_key :tasks, :users, column: :responsible_id
    add_foreign_key :tasks, :users, column: :delegated_user_id

    add_check_constraint :tasks,
                         "(creator_id IS NOT NULL OR responsible_id IS NOT NULL OR delegated_user_id IS NOT NULL)",
                         name: "tasks_have_owner_context"
  end

  def down
    remove_check_constraint :tasks, name: "tasks_have_owner_context"

    remove_foreign_key :tasks, column: :delegated_user_id
    remove_foreign_key :tasks, column: :responsible_id
    remove_foreign_key :tasks, column: :creator_id

    remove_index :tasks, :delegated_user_id
    remove_index :tasks, :creator_id

    backfill_responsible_ids_for_rollback!
    if migration_task.where(responsible_id: nil).exists?
      raise ActiveRecord::IrreversibleMigration, "cannot safely restore tasks.responsible_id for tasks without creator, responsible, or delegated_user"
    end

    change_column_null :tasks, :responsible_id, false

    remove_column :tasks, :deactivated_at
    remove_column :tasks, :cancellation_reason
    remove_column :tasks, :accepted_at
    remove_column :tasks, :delegated_user_id
    remove_column :tasks, :creator_id
    remove_column :tasks, :completion_date

    rename_column :tasks, :name, :title
  end

  private

    def create_placeholder_users_for_legacy_responsible_ids
      legacy_responsible_ids = migration_task.where.not(responsible_id: nil).distinct.pluck(:responsible_id)
      missing_ids = legacy_responsible_ids - migration_user.where(id: legacy_responsible_ids).pluck(:id)
      return if missing_ids.empty?

      timestamp = Time.current

      migration_user.insert_all(
        missing_ids.map do |user_id|
          password_salt = SecureRandom.hex(PASSWORD_SALT_BYTES)

          {
            id: user_id,
            email: "legacy-task-owner-#{user_id}@example.invalid",
            password_digest: digest_password(SecureRandom.urlsafe_base64(64), password_salt),
            password_salt: password_salt,
            role: "doctor",
            name: "Legacy",
            last_name: "Task Owner",
            created_at: timestamp,
            updated_at: timestamp
          }
        end
      )

      reset_user_primary_key_sequence!
    end

    def backfill_responsible_ids_for_rollback!
      migration_task.where(responsible_id: nil).update_all("responsible_id = COALESCE(responsible_id, delegated_user_id, creator_id)")
    end

    def reset_user_primary_key_sequence!
      sequence_name = connection.serial_sequence("users", "id")
      return if sequence_name.blank?

      connection.execute("SELECT setval(#{connection.quote(sequence_name)}, (SELECT COALESCE(MAX(id), 1) FROM users))")
    end

    def digest_password(password, salt)
      OpenSSL::PKCS5.pbkdf2_hmac(
        password.to_s,
        salt.to_s,
        PASSWORD_ITERATIONS,
        PASSWORD_DERIVED_KEY_LENGTH_BYTES,
        PASSWORD_DIGEST_ALGORITHM
      ).unpack1("H*")
    end

    def migration_task
      @migration_task ||= Class.new(ActiveRecord::Base) do
        self.table_name = "tasks"
      end
    end

    def migration_user
      @migration_user ||= Class.new(ActiveRecord::Base) do
        self.table_name = "users"
      end
    end
end
