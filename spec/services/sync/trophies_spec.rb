require "rails_helper"

RSpec.describe Sync::Trophies do
  let(:account) { create(:account) }
  let(:client) { stub_psn_client }
  let(:title) { psn_trophy_title }
  let(:trophies_resource) { instance_double(PSN::Resources::Trophies) }

  before do
    allow(client).to receive(:trophies).and_return(trophies_resource)
    allow(trophies_resource).to receive(:titles).and_return([title].lazy)
    allow(trophies_resource).to receive(:summary).and_return(psn_trophy_summary)
    allow(trophies_resource).to receive(:earned)
      .with(np_communication_id: "NPWR11111_00", platform: "PS5")
      .and_return([
        psn_trophy(id: 0, grade: :platinum),
        psn_trophy(id: 1, earned: true, earned_at: Time.utc(2024, 4, 30, 12))
      ].lazy)
    profiles_resource = instance_double(PSN::Resources::Profiles)
    allow(client).to receive(:profiles).and_return(profiles_resource)
    allow(profiles_resource).to receive(:find)
      .and_return(PSN::Profile.new(online_id: "test_user", account_id: "123456789",
                                   avatar_url: "https://example.com/avatar.jpg",
                                   plus: true, about_me: nil, languages: nil, verified: false,
                                   trophy_summary: psn_trophy_summary,
                                   online: false, platform: nil, last_online_at: nil, raw: {}))
  end

  it "creates the game, its trophies, and the account's earned state" do
    expect(described_class.call(account)).to eq(1)

    game = Game.find_by!(np_communication_id: "NPWR11111_00")
    expect(game).to have_attributes(name: "Astro Bot", platform: "PS5", total_bronze: 20)
    expect(game.trophies.count).to eq(2)

    account_game = account.account_games.find_by!(game:)
    expect(account_game).to have_attributes(progress: 40, earned_bronze: 4)

    earned = account.account_trophies.joins(:trophy).find_by!(trophies: { psn_trophy_id: 1 })
    expect(earned).to have_attributes(earned: true, earned_at: Time.utc(2024, 4, 30, 12))
    unearned = account.account_trophies.joins(:trophy).find_by!(trophies: { psn_trophy_id: 0 })
    expect(unearned.earned).to be(false)

    # Verify rarity is persisted
    trophies = game.trophies.order(:psn_trophy_id)
    expect(trophies.map(&:rarity_percent)).to all(eq(12.5))
  end

  it "updates the account summary caches" do
    described_class.call(account)
    expect(account.reload).to have_attributes(
      trophy_level: 300, earned_platinum: 1,
      avatar_url: "https://example.com/avatar.jpg"
    )
    expect(account.last_synced_at).to be_present
  end

  it "is idempotent and skips unchanged games on re-sync" do
    described_class.call(account)
    described_class.call(account)
    expect(trophies_resource).to have_received(:earned).once
    expect(Game.count).to eq(1)
    expect(account.account_trophies.count).to eq(2)
  end

  it "rolls back the account_game update when the trophy fetch fails mid-game" do
    allow(trophies_resource).to receive(:earned).and_raise(PSN::APIError, "boom")
    expect { described_class.call(account) }.to raise_error(PSN::APIError)

    game = Game.find_by!(np_communication_id: "NPWR11111_00")
    expect(account.account_games.find_by(game:)&.progress).not_to eq(40)
    expect(account.account_trophies.count).to eq(0)
  end

  it "re-fetches trophies when a game's progress has changed" do
    described_class.call(account)

    updated_title = psn_trophy_title(progress: 60, last_updated: "2024-06-01T10:00:00Z")
    allow(trophies_resource).to receive(:titles).and_return([updated_title].lazy)
    described_class.call(account)

    expect(trophies_resource).to have_received(:earned).twice
    expect(account.account_games.sole.progress).to eq(60)
  end
end
