require "rails_helper"

RSpec.describe SpendSummary do
  it "totals purchases minus refunds per account and currency, split by year" do
    account = create(:account)
    create(:psn_transaction, account:, kind: "purchase", amount_minor: 5000, currency: "GBP",
           occurred_at: Time.zone.local(2023, 3, 1))
    create(:psn_transaction, account:, kind: "purchase", amount_minor: 3000, currency: "GBP",
           occurred_at: Time.zone.local(2024, 3, 1))
    create(:psn_transaction, account:, kind: "refund", amount_minor: 1000, currency: "GBP",
           occurred_at: Time.zone.local(2024, 4, 1))
    create(:psn_transaction, account:, kind: "wallet", amount_minor: 2000, currency: "GBP",
           occurred_at: Time.zone.local(2024, 4, 1))
    create(:psn_transaction, account:, kind: "purchase", amount_minor: 900, currency: "USD",
           occurred_at: Time.zone.local(2024, 5, 1))

    totals = described_class.call.fetch(account)
    gbp = totals.find { |t| t.currency == "GBP" }
    expect(gbp).to have_attributes(purchases: 8000, refunds: 1000, wallet: 2000, net: 7000)
    expect(gbp.by_year).to eq({ 2024 => 2000, 2023 => 5000 })
    expect(totals.find { |t| t.currency == "USD" }.net).to eq(900)
  end

  it "lists the biggest purchases" do
    account = create(:account)
    small = create(:psn_transaction, account:, amount_minor: 100)
    big = create(:psn_transaction, account:, amount_minor: 9999)
    expect(described_class.biggest_purchases(limit: 1)).to eq([big])
  end
end
