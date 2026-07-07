class AddAvatarUrlToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :avatar_url, :string
  end
end
