require "rails_helper"

RSpec.describe DashboardStats do
  let(:main) { create(:account, current: true) }
  let(:alt) { create(:account) }

  it "counts trophies unique to a single account" do
    t_shared = create(:trophy)
    t_solo = create(:trophy)
    create(:account_trophy, account: main, trophy: t_shared, earned: true)
    create(:account_trophy, account: alt, trophy: t_shared, earned: true)
    create(:account_trophy, account: alt, trophy: t_solo, earned: true)

    stats = described_class.call(main)
    expect(stats.unique_counts[alt.id]).to eq(1)
    expect(stats.unique_counts[main.id]).to be_nil
  end

  it "picks closest-to-done and biggest-gap incomplete games" do
    near = create(:game, name: "Near")
    far = create(:game, name: "Far")
    create(:account_game, account: main, game: near)
    create(:account_game, account: main, game: far)
    2.times { create(:account_trophy, account: alt, trophy: create(:trophy, game: near), earned: true) }
    create(:account_trophy, account: main, trophy: near.trophies.first, earned: true)
    5.times { create(:account_trophy, account: alt, trophy: create(:trophy, game: far), earned: true) }

    stats = described_class.call(main)
    expect(stats.closest.game).to eq(near)
    expect(stats.biggest_gap.game).to eq(far)
    expect(stats.not_owned_count).to eq(0)
  end
end
