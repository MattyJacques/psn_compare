class SyncRun < ApplicationRecord
  KINDS = %w[trophies entitlements transactions].freeze
  STATUSES = %w[running succeeded failed rate_limited].freeze

  belongs_to :account

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  # Newest run per kind for one account's runs.
  def self.latest_per_kind
    order(created_at: :desc).group_by(&:kind).transform_values(&:first)
  end
end
