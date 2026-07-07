class AccountTrophy < ApplicationRecord
  belongs_to :account
  belongs_to :trophy

  validates :trophy_id, uniqueness: { scope: :account_id }
end
