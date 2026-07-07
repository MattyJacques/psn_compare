require "rails_helper"

RSpec.describe OwnershipMatrix do
  let(:a) { create(:account) }
  let(:b) { create(:account) }

  it "groups entitlements by product across accounts and flags duplicates" do
    create(:entitlement, account: a, name: "Astro Bot", product_id: "EP-ASTRO")
    create(:entitlement, account: b, name: "ASTRO BOT", product_id: "EP-ASTRO")
    create(:entitlement, account: b, name: "Bloodborne", product_id: nil)

    rows = described_class.call
    expect(rows.map(&:name)).to eq(["Astro Bot", "Bloodborne"])

    astro = rows.first
    expect(astro.by_account_id.keys).to contain_exactly(a.id, b.id)
    expect(astro).to be_duplicate
    expect(rows.last).not_to be_duplicate
  end

  it "groups by case-insensitive name when there is no product id" do
    create(:entitlement, account: a, name: "Bloodborne", product_id: nil)
    create(:entitlement, account: b, name: "BLOODBORNE", product_id: nil)
    expect(described_class.call.size).to eq(1)
  end

  it "excludes DLC unless asked for it" do
    create(:entitlement, account: a, name: "Base Game", kind: "game")
    create(:entitlement, account: a, name: "Season Pass", kind: "dlc")
    expect(described_class.call.map(&:name)).to eq(["Base Game"])
    expect(described_class.call(include_dlc: true).map(&:name)).to eq(["Base Game", "Season Pass"])
  end
end
