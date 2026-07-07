require "rails_helper"

RSpec.describe "Re-earn checklist", type: :request do
  let(:main) { create(:account, current: true) }
  let(:alt) { create(:account, label: "Matty_JPN") }
  let(:game) { create(:game, name: "Elden Ring") }
  let(:missing_trophy) { create(:trophy, game:, name: "Age of the Stars", rarity_percent: 14.2) }

  before do
    done = create(:trophy, game:)
    [ done, missing_trophy ].each { |t| create(:account_trophy, account: alt, trophy: t, earned: true, earned_at: Time.zone.parse("2022-08-02")) }
    create(:account_trophy, account: main, trophy: done, earned: true, earned_at: Time.zone.parse("2024-01-11"))
  end

  it "renders the by-game checklist with progress and missing trophies" do
    get reearn_path
    expect(response.body).to include("games to finish")
    expect(response.body).to include("Elden Ring")
    expect(response.body).to include("1 / 2")
    expect(response.body).to include("1 left")
    expect(response.body).to include("Age of the Stars")
    expect(response.body).to include("won&#39;t earn")
  end

  it "renders the backlog ranked list" do
    get reearn_backlog_path
    expect(response.body).to include("trophies to go")
    expect(response.body).to include("Age of the Stars")
    expect(response.body).to include("14.2%")
    expect(response.body).to include("Matty_JPN")
  end

  it "renders skipped trophies struck out with undo" do
    extra = create(:trophy, game:)
    create(:account_trophy, account: alt, trophy: extra, earned: true, earned_at: Time.zone.parse("2022-08-02"))
    create(:trophy_skip, trophy: missing_trophy)
    get reearn_path
    expect(response.body).to include("WON'T EARN")
    expect(response.body).to include("undo")
    expect(response.body).to include("· 1 skipped")
    expect(response.body).to include("Skipped · 1")
  end

  it "excludes skipped trophies from the backlog and counts them in the chip" do
    create(:trophy_skip, trophy: missing_trophy)
    get reearn_backlog_path
    expect(response.body).to include("0 trophies to go")
    expect(response.body).to include("Skipped · 1")
    expect(response.body).not_to include("Age of the Stars")
  end
end
