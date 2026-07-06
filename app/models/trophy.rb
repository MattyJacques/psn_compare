class Trophy < ApplicationRecord
  belongs_to :game
  has_many :account_trophies, dependent: :destroy

  validates :psn_trophy_id, presence: true, uniqueness: { scope: :game_id }
end
