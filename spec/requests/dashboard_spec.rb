require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  it "shows each account's level, counts, spend, and sync state" do
    account = create(:account, label: "Main", current: true, trophy_level: 420,
                     earned_platinum: 5, last_synced_at: 2.hours.ago)
    create(:psn_transaction, account:, kind: "purchase", amount_minor: 5000, currency: "GBP")
    create(:psn_transaction, account:, kind: "refund", amount_minor: 1000, currency: "GBP")
    create(:sync_run, account:, kind: "trophies", status: "failed", error_message: "boom")

    get root_path
    expect(response.body).to include("Main", "420", "£40.00", "boom")
  end

  it "renders an empty state with a link to add an account" do
    get root_path
    expect(response.body).to include("Add account")
  end
end
