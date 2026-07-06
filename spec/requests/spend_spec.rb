require "rails_helper"

RSpec.describe "Spend", type: :request do
  it "shows per-account totals and biggest purchases" do
    account = create(:account, label: "Main")
    create(:psn_transaction, account:, amount_minor: 6999, currency: "GBP",
           description: "Astro Bot", occurred_at: Time.zone.local(2024, 2, 1))
    get spend_index_path
    expect(response.body).to include("Main", "£69.99", "Astro Bot")
  end
end
