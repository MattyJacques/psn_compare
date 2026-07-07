require "rails_helper"

RSpec.describe "Purchases", type: :request do
  let(:main) { create(:account, current: true, label: "Matty_Hunter") }
  let(:alt) { create(:account, label: "CoOpCouch") }

  before do
    create(:entitlement, account: alt, kind: "game", name: "Persona 5 Royal")
    create(:psn_transaction, account: main, kind: "purchase", description: "Persona 5 Royal",
           amount_minor: 1999, currency: "GBP", occurred_at: Time.zone.parse("2026-04-22"))
    create(:psn_transaction, account: main, kind: "refund", description: "Stellar Blade",
           amount_minor: 5999, currency: "GBP", occurred_at: Time.zone.parse("2026-04-30"),
           psn_transaction_id: "r1")
  end

  it "shows lifetime spend, the ledger, and 2nd-copy highlighting" do
    get spend_index_path
    expect(response.body).to include("Lifetime spend")
    expect(response.body).to include("£19.99")
    expect(response.body).to include("2ND COPY")
    expect(response.body).to include("refund")
    expect(response.body).to include("−£59.99")
  end

  it "filters to bought-twice rows" do
    get spend_index_path(filter: "twice")
    expect(response.body).to include("Persona 5 Royal")
    expect(response.body).not_to include("Stellar Blade")
  end

  it "skips nil-currency totals from spend summaries" do
    # Add a nil-currency purchase; with existing setup, only this would produce "40.00"
    # when currency is nil, format_money renders without symbol
    create(:psn_transaction, account: main, kind: "purchase", description: "Unknown Store",
           amount_minor: 4000, currency: nil, occurred_at: Time.zone.parse("2026-05-15"),
           psn_transaction_id: "nilcur")
    get spend_index_path
    expect(response).to be_successful
    # The nil-currency amount should not leak into the summary; check transaction table
    # doesn't render the nil-currency item (filtered by where.not(currency: nil))
    expect(response.body).not_to include("Unknown Store")
  end
end
