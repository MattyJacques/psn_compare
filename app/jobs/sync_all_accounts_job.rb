class SyncAllAccountsJob < ApplicationJob
  queue_as :default

  def perform
    Account.where(needs_reauth: false).find_each { |account| SyncAccountJob.perform_later(account) }
  end
end
