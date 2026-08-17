class AddWebauthnIdToUsers < ActiveRecord::Migration[7.2]
  def up
    add_column :users, :webauthn_id, :string

    User.reset_column_information
    User.find_each do |user|
      user.update_column(:webauthn_id, WebAuthn.generate_user_id)
    end

    change_column_null :users, :webauthn_id, false
    add_index :users, :webauthn_id, unique: true
  end

  def down
    remove_index :users, :webauthn_id
    remove_column :users, :webauthn_id
  end
end
