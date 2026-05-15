class HardenTagDeleteTriggers < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION prevent_system_tag_mutation()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'system tags cannot be updated or deleted';
      END;
      $$;

      CREATE OR REPLACE FUNCTION prevent_tag_delete()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'tags must be deactivated instead of deleted';
      END;
      $$;

      CREATE OR REPLACE FUNCTION prevent_task_tag_delete()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'task tags must be deactivated instead of deleted';
      END;
      $$;

      DROP TRIGGER IF EXISTS prevent_system_tag_mutation ON tags;
      DROP TRIGGER IF EXISTS prevent_tag_delete ON tags;
      DROP TRIGGER IF EXISTS prevent_tag_truncate ON tags;
      DROP TRIGGER IF EXISTS prevent_task_tag_delete ON task_tags;
      DROP TRIGGER IF EXISTS prevent_task_tag_truncate ON task_tags;

      CREATE TRIGGER prevent_system_tag_mutation
      BEFORE UPDATE ON tags
      FOR EACH ROW
      WHEN (OLD.is_system_tag)
      EXECUTE FUNCTION prevent_system_tag_mutation();

      CREATE TRIGGER prevent_tag_delete
      BEFORE DELETE ON tags
      FOR EACH ROW
      EXECUTE FUNCTION prevent_tag_delete();

      CREATE TRIGGER prevent_tag_truncate
      BEFORE TRUNCATE ON tags
      FOR EACH STATEMENT
      EXECUTE FUNCTION prevent_tag_delete();

      CREATE TRIGGER prevent_task_tag_delete
      BEFORE DELETE ON task_tags
      FOR EACH ROW
      EXECUTE FUNCTION prevent_task_tag_delete();

      CREATE TRIGGER prevent_task_tag_truncate
      BEFORE TRUNCATE ON task_tags
      FOR EACH STATEMENT
      EXECUTE FUNCTION prevent_task_tag_delete();
    SQL
  end

  def down
    execute <<~SQL
      CREATE OR REPLACE FUNCTION prevent_system_tag_mutation()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'system tags cannot be updated or deleted';
      END;
      $$;

      CREATE OR REPLACE FUNCTION prevent_tag_delete()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'tags must be deactivated instead of deleted';
      END;
      $$;

      CREATE OR REPLACE FUNCTION prevent_task_tag_delete()
      RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      BEGIN
        RAISE EXCEPTION 'task tags must be deactivated instead of deleted';
      END;
      $$;

      DROP TRIGGER IF EXISTS prevent_task_tag_truncate ON task_tags;
      DROP TRIGGER IF EXISTS prevent_task_tag_delete ON task_tags;
      DROP TRIGGER IF EXISTS prevent_tag_truncate ON tags;
      DROP TRIGGER IF EXISTS prevent_tag_delete ON tags;
      DROP TRIGGER IF EXISTS prevent_system_tag_mutation ON tags;

      CREATE TRIGGER prevent_system_tag_mutation
      BEFORE UPDATE ON tags
      FOR EACH ROW
      WHEN (OLD.is_system_tag)
      EXECUTE FUNCTION prevent_system_tag_mutation();

      CREATE TRIGGER prevent_tag_delete
      BEFORE DELETE ON tags
      FOR EACH ROW
      EXECUTE FUNCTION prevent_tag_delete();

      CREATE TRIGGER prevent_tag_truncate
      BEFORE TRUNCATE ON tags
      FOR EACH STATEMENT
      EXECUTE FUNCTION prevent_tag_delete();

      CREATE TRIGGER prevent_task_tag_delete
      BEFORE DELETE ON task_tags
      FOR EACH ROW
      EXECUTE FUNCTION prevent_task_tag_delete();

      CREATE TRIGGER prevent_task_tag_truncate
      BEFORE TRUNCATE ON task_tags
      FOR EACH STATEMENT
      EXECUTE FUNCTION prevent_task_tag_delete();
    SQL
  end
end
