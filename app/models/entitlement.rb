class Entitlement < ApplicationRecord
  KINDS = %w[game dlc other].freeze

  belongs_to :account

  validates :entitlement_id, presence: true, uniqueness: { scope: :account_id }
  validates :kind, inclusion: { in: KINDS }

  scope :games, -> { where(kind: "game") }

  # Ownership-matrix grouping key: product when Sony provides one, name otherwise.
  def product_key = product_id.presence || name.to_s.downcase
end
