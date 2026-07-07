class SyncRun < ApplicationRecord
  KINDS = %w[trophies entitlements transactions].freeze
  STATUSES = %w[running succeeded failed rate_limited].freeze

  belongs_to :account

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  # Any sync-run change refreshes pages subscribed to the sync_status stream.
  broadcasts_refreshes_to ->(_run) { "sync_status" }

  # Newest run per kind. Sorts in memory so a preloaded association
  # (accounts index) doesn't trigger one query per account.
  def self.latest_per_kind
    all.sort_by(&:created_at).reverse.group_by(&:kind).transform_values(&:first)
  end
end
