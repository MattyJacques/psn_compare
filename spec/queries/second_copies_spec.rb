require "rails_helper"

RSpec.describe SecondCopies do
  it "flags purchases of games already owned on another account" do
    owner = create(:account)
    buyer = create(:account, label: "Main")
    create(:entitlement, account: owner, kind: "game", name: "Persona 5 Royal")
    dup = create(:psn_transaction, account: buyer, kind: "purchase", description: "Persona 5 Royal")
    fresh = create(:psn_transaction, account: buyer, kind: "purchase", description: "Stellar Blade",
                   psn_transaction_id: "other")
    own_repurchase = create(:psn_transaction, account: owner, kind: "purchase",
                            description: "Persona 5 Royal", psn_transaction_id: "own")

    ids = described_class.transaction_ids
    expect(ids).to include(dup.id)
    expect(ids).not_to include(fresh.id, own_repurchase.id)
  end
end
