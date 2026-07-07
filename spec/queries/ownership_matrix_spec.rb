require "rails_helper"

RSpec.describe OwnershipMatrix do
  let(:a) { create(:account) }
  let(:b) { create(:account) }

  it "groups entitlements by product across accounts and flags duplicates" do
    create(:entitlement, account: a, name: "Astro Bot", product_id: "EP-ASTRO")
    create(:entitlement, account: b, name: "ASTRO BOT", product_id: "EP-ASTRO")
    create(:entitlement, account: b, name: "Bloodborne", product_id: nil)

    rows = described_class.call
    expect(rows.map(&:name)).to eq([ "Astro Bot", "Bloodborne" ])

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
    expect(described_class.call.map(&:name)).to eq([ "Base Game" ])
    expect(described_class.call(include_dlc: true).map(&:name)).to eq([ "Base Game", "Season Pass" ])
  end

  it "annotates rows with re-earn candidate counts for the main account" do
    main = create(:account, current: true)
    alt = create(:account)
    game = create(:game, name: "Yakuza 0")
    create(:account_trophy, account: alt, trophy: create(:trophy, game:), earned: true)
    create(:entitlement, account: alt, kind: "game", name: "Yakuza 0")

    row = described_class.call(main: main).find { |r| r.name == "Yakuza 0" }
    expect(row.reearn_count).to eq(1)
  end

  it "prefers longest prefix match for re-earn candidate counts" do
    main = create(:account, current: true)
    alt = create(:account)
    gravity = create(:game, name: "Gravity")
    gravity_rush = create(:game, name: "Gravity Rush")

    # Create 2 trophies for "Gravity" earned by alt
    create(:account_trophy, account: alt, trophy: create(:trophy, game: gravity), earned: true)
    create(:account_trophy, account: alt, trophy: create(:trophy, game: gravity), earned: true)

    # Create 1 trophy for "Gravity Rush" earned by alt
    create(:account_trophy, account: alt, trophy: create(:trophy, game: gravity_rush), earned: true)

    # Create entitlements for both games on alt
    create(:entitlement, account: alt, kind: "game", name: "Gravity")
    create(:entitlement, account: alt, kind: "game", name: "Gravity Rush")

    # Create entitlement named "Gravity Rush Remastered" that should match "Gravity Rush" (2-trophy count), not "Gravity" (1-trophy count)
    create(:entitlement, account: alt, kind: "game", name: "Gravity Rush Remastered")

    rows = described_class.call(main: main)
    row = rows.find { |r| r.name == "Gravity Rush Remastered" }
    expect(row.reearn_count).to eq(1)
  end
end
