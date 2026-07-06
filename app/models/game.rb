class Game < ApplicationRecord
  has_many :trophies, dependent: :destroy
  has_many :account_games, dependent: :destroy

  validates :np_communication_id, presence: true, uniqueness: true
  validates :name, presence: true
end
