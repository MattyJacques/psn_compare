require "rails_helper"

RSpec.describe ReearnBacklog do
  let(:main) { create(:account, current: true) }
  let(:alt) { create(:account, label: "Matty_JPN") }
  let(:game) { create(:game) }

  def earn(trophy, account, at: Time.zone.parse("2022-01-01"))
    create(:account_trophy, account:, trophy:, earned: true, earned_at: at)
  end

  it "lists candidates sorted most-common-first with first-earned info" do
    common = create(:trophy, game:, rarity_percent: 92.1)
    rare = create(:trophy, game:, rarity_percent: 4.1)
    earned_on_main = create(:trophy, game:, rarity_percent: 50)
    skipped = create(:trophy, game:, rarity_percent: 60)
    [ common, rare, earned_on_main, skipped ].each { |t| earn(t, alt) }
    earn(earned_on_main, main)
    create(:trophy_skip, trophy: skipped)

    rows = described_class.call(main)
    expect(rows.map(&:trophy)).to eq([ common, rare ])
    expect(rows.first.first_earned_label).to eq("Matty_JPN")
    expect(described_class.call(main, sort: "rare").map(&:trophy)).to eq([ rare, common ])
  end

  it "filters platinums, ownership, and skipped" do
    plat = create(:trophy, game:, trophy_type: "platinum")
    bronze = create(:trophy, game:, trophy_type: "bronze")
    skipped = create(:trophy, game:)
    [ plat, bronze, skipped ].each { |t| earn(t, alt) }
    create(:trophy_skip, trophy: skipped)
    create(:account_game, account: main, game:)

    expect(described_class.call(main, filter: "platinum").map(&:trophy)).to eq([ plat ])
    expect(described_class.call(main, filter: "owned").size).to eq(2)
    expect(described_class.call(main, filter: "skipped").map(&:trophy)).to eq([ skipped ])
  end
end
