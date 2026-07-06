class Account < ApplicationRecord
  encrypts :refresh_token

  has_many :account_games, dependent: :destroy
  has_many :account_trophies, dependent: :destroy
  has_many :games, through: :account_games

  validates :label, presence: true, uniqueness: true

  def self.current = find_by(current: true)

  def make_current!
    transaction do
      Account.where.not(id:).update_all(current: false)
      update!(current: true)
    end
  end
end
