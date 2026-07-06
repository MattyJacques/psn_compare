class AccountGame < ApplicationRecord
  belongs_to :account
  belongs_to :game

  validates :game_id, uniqueness: { scope: :account_id }
end
