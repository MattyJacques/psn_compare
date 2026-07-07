class PsnTransaction < ApplicationRecord
  KINDS = %w[purchase addon subscription refund wallet].freeze

  belongs_to :account

  validates :psn_transaction_id, presence: true, uniqueness: { scope: :account_id }
  validates :kind, inclusion: { in: KINDS }

  scope :purchases, -> { where(kind: "purchase") }
  scope :refunds, -> { where(kind: "refund") }
  scope :wallet_funding, -> { where(kind: "wallet") }
  scope :addons, -> { where(kind: "addon") }
  scope :subscriptions, -> { where(kind: "subscription") }
  scope :spend_kinds, -> { where(kind: %w[purchase addon subscription]) }
end
