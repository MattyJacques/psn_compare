class SyncAccountJob < ApplicationJob
  queue_as :default

  def perform(account)
    SyncJob::SERVICES.each_key { |kind| SyncJob.perform_later(account, kind) }
  end
end
