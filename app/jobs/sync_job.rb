class SyncJob < ApplicationJob
  queue_as :default

  SERVICES = {
    "trophies" => Sync::Trophies,
    "entitlements" => Sync::Entitlements,
    "transactions" => Sync::Transactions
  }.freeze

  # PSN failures land in the sync_run record (the dashboard renders them);
  # raising would just make Solid Queue retry blindly.
  def perform(account, kind)
    run = account.sync_runs.create!(kind:, status: "running", started_at: Time.current)
    count = SERVICES.fetch(kind).call(account)
    run.update!(status: "succeeded", items_synced: count, completed_at: Time.current)
  rescue PSN::RateLimitError => e
    run.update!(status: "rate_limited", error_message: e.message, completed_at: Time.current)
    self.class.set(wait: e.retry_after || 60).perform_later(account, kind)
  rescue PSN::Error => e
    run.update!(status: "failed", error_message: e.message, completed_at: Time.current)
  end
end
