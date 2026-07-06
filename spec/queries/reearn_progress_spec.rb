require "rails_helper"

RSpec.describe ReearnProgress do
  let(:current) { create(:account, current: true) }
  let(:old) { create(:account) }

  it "computes the baseline as trophies earned by anyone, progress by the current account" do
    game = create(:game)
    t1, t2, t3, t4 = create_list(:trophy, 4, game:)

    create(:account_trophy, account: old, trophy: t1)                  # old only -> to re-earn
    create(:account_trophy, account: old, trophy: t2)                  # earned by both
    create(:account_trophy, account: current, trophy: t2)
    create(:account_trophy, account: current, trophy: t3)              # current only -> still counts
    create(:account_trophy, account: current, trophy: t4, earned: false) # unearned -> not in baseline

    result = described_class.call(current)
    expect(result.total).to eq(3)
    expect(result.reearned).to eq(2)
    expect(result.percent).to eq(67)
  end

  it "reports per-game progress with complete games sorted last" do
    done = create(:game, name: "Done Game")
    pending = create(:game, name: "Pending Game")
    done_trophy = create(:trophy, game: done)
    pending_trophy = create(:trophy, game: pending)
    create(:account_trophy, account: old, trophy: done_trophy)
    create(:account_trophy, account: current, trophy: done_trophy)
    create(:account_trophy, account: old, trophy: pending_trophy)

    games = described_class.call(current).games
    expect(games.map { |g| g.game.name }).to eq(["Pending Game", "Done Game"])
    expect(games.last).to be_complete
  end

  it "handles an empty baseline" do
    result = described_class.call(current)
    expect(result.total).to eq(0)
    expect(result.percent).to eq(0)
  end
end
