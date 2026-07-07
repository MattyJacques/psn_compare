require "rails_helper"

RSpec.describe "Trophy comparison", type: :request do
  let(:main) { create(:account, current: true, label: "Matty_Hunter") }
  let(:alt) { create(:account, label: "Matty_JPN") }
  let(:game) { create(:game, name: "Elden Ring") }

  before do
    earned = create(:trophy, game:, name: "Elden Lord")
    candidate = create(:trophy, game:, name: "Age of the Stars")
    [ earned, candidate ].each { |t| create(:account_trophy, account: alt, trophy: t, earned: true, earned_at: Time.zone.parse("2022-06-09 15:03")) }
    create(:account_trophy, account: main, trophy: earned, earned: true, earned_at: Time.zone.parse("2024-03-14 21:47"))
  end

  it "renders the per-trophy matrix with re-earn highlighting" do
    get trophy_comparison_index_path(game_id: game.id)
    expect(response.body).to include("Elden Ring")
    expect(response.body).to include("Matty_Hunter · main")
    expect(response.body).to include("RE-EARN")
    expect(response.body).to include("14 Mar 2024")
    expect(response.body).to include("21:47")
  end

  it "filters to missing-on-main" do
    get trophy_comparison_index_path(game_id: game.id, filter: "missing")
    expect(response.body).to include("Age of the Stars")
    expect(response.body).not_to include("Elden Lord")
  end

  it "respects search in All chip count" do
    get trophy_comparison_index_path(game_id: game.id, q: "Age")
    expect(response.body).to include("All 1")
    expect(response.body).to include("Age of the Stars")
    expect(response.body).not_to include("Elden Lord")
  end
end
