class Account < ApplicationRecord
  encrypts :refresh_token

  has_many :account_games, dependent: :destroy
  has_many :account_trophies, dependent: :destroy
  has_many :games, through: :account_games
  has_many :entitlements, dependent: :destroy
  has_many :psn_transactions, dependent: :destroy
  has_many :sync_runs, dependent: :destroy

  validates :label, presence: true, uniqueness: true

  def self.current = find_by(current: true)

  def make_current!
    transaction do
      Account.where.not(id:).update_all(current: false)
      update!(current: true)
    end
  end

  # Yields an authenticated PSN client. The gem rotates the refresh token on
  # use, so persist whatever it ends up holding — even if the block raised.
  def with_client
    client = PSN::Client.new(refresh_token: refresh_token)
    yield client
  rescue PSN::AuthenticationError
    update!(needs_reauth: true)
    raise
  ensure
    if client&.refresh_token.present? && client.refresh_token != refresh_token
      update!(refresh_token: client.refresh_token)
    end
  end

  def reauthenticate!(npsso)
    client = PSN::Client.new(npsso: npsso)
    client.access_token # force the exchange now so bad tokens fail here
    update!(refresh_token: client.refresh_token, needs_reauth: false)
  end
end
