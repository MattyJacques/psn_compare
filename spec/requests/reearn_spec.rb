require "rails_helper"

RSpec.describe "Re-earn tracker", type: :request do
  it "asks you to pick a current account when none is set" do
    get reearn_path
    expect(response.body).to include("No current account")
  end

  it "shows overall and per-game progress with the trophy checklist" do
    current = create(:account, current: true, label: "Main")
    old = create(:account, label: "Old")
    game = create(:game, name: "Astro Bot")
    trophy = create(:trophy, game:, name: "First Step")
    create(:account_trophy, account: old, trophy:, earned_at: Time.zone.local(2015, 1, 1))

    get reearn_path
    expect(response.body).to include("Astro Bot", "First Step", "0%", "Old")
  end
end
