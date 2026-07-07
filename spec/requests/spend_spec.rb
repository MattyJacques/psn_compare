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
end
