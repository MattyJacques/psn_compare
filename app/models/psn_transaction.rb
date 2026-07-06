class PsnTransaction < ApplicationRecord
  KINDS = %w[purchase refund wallet].freeze

  belongs_to :account

  validates :psn_transaction_id, presence: true, uniqueness: { scope: :account_id }
  validates :kind, inclusion: { in: KINDS }

  scope :purchases, -> { where(kind: "purchase") }
  scope :refunds, -> { where(kind: "refund") }
  scope :wallet_funding, -> { where(kind: "wallet") }
end
