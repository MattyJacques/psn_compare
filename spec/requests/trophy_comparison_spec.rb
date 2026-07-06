require "rails_helper"

RSpec.describe "Trophy comparison", type: :request do
  it "shows each game once with per-account progress" do
    a = create(:account, label: "Main")
    b = create(:account, label: "Alt")
    game = create(:game, name: "Astro Bot")
    create(:account_game, account: a, game:, progress: 100, earned_platinum: 1)
    create(:account_game, account: b, game:, progress: 40)

    get trophy_comparison_index_path
    expect(response.body).to include("Astro Bot", "Main", "Alt", "100%", "40%")
    expect(response.body.scan("Astro Bot").size).to eq(1)
  end
end
