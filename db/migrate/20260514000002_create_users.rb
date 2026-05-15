class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :password_salt, null: false
      t.string :role, null: false
      t.string :name, null: false
      t.string :last_name, null: false
      t.string :auth_token_digest

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, [ :name, :last_name ]
    add_index :users, :auth_token_digest, unique: true
  end
end
