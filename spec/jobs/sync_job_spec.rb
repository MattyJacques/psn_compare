require "rails_helper"

RSpec.describe SyncJob do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }

  it "records a succeeded run with the item count" do
    allow(Sync::Trophies).to receive(:call).with(account).and_return(42)
    described_class.perform_now(account, "trophies")
    run = account.sync_runs.sole
    expect(run).to have_attributes(kind: "trophies", status: "succeeded", items_synced: 42)
    expect(run.completed_at).to be_present
  end

  it "marks the run rate_limited and re-enqueues itself with the retry delay" do
    allow(Sync::Entitlements).to receive(:call)
      .and_raise(PSN::RateLimitError.new("slow down", retry_after: 120))
    expect {
      described_class.perform_now(account, "entitlements")
    }.to have_enqueued_job(described_class).with(account, "entitlements")
    expect(account.sync_runs.sole.status).to eq("rate_limited")
  end

  it "records failures without raising" do
    allow(Sync::Transactions).to receive(:call).and_raise(PSN::APIError, "boom")
    expect { described_class.perform_now(account, "transactions") }.not_to raise_error
    expect(account.sync_runs.sole).to have_attributes(status: "failed", error_message: "boom")
  end

  it "SyncAccountJob fans out one SyncJob per kind" do
    expect {
      SyncAccountJob.perform_now(account)
    }.to have_enqueued_job(described_class).exactly(3).times
  end

  it "SyncAllAccountsJob skips accounts needing reauth" do
    stale = create(:account, needs_reauth: true)
    expect {
      SyncAllAccountsJob.perform_now
    }.to have_enqueued_job(SyncAccountJob).with(account).exactly(:once)
    expect(SyncAccountJob).not_to have_been_enqueued.with(stale)
  end
end
