require "rails_helper"

RSpec.describe ReearnProgress do
  let(:main) { create(:account, current: true) }
  let(:alt) { create(:account) }

  context "with existing data" do
    let(:game) { create(:game) }
    let!(:t1) { create(:trophy, game:) }
    let!(:t2) { create(:trophy, game:) }
    let!(:t3) { create(:trophy, game:) }

    before do
      # alt earned all three; main re-earned t1; t3 is skipped
      [t1, t2, t3].each { |t| create(:account_trophy, account: alt, trophy: t, earned: true, earned_at: Time.zone.parse("2022-05-01 10:00")) }
      create(:account_trophy, account: main, trophy: t1, earned: true, earned_at: Time.zone.parse("2024-03-14 21:47"))
      create(:trophy_skip, trophy: t3)
    end

    it "excludes skipped trophies from every denominator" do
      result = described_class.call(main)
      expect(result.total).to eq(2)          # t3 skipped
      expect(result.reearned).to eq(1)
      expect(result.skipped).to eq(1)
      expect(result.percent).to eq(50.0)
      expect(result.to_go).to eq(1)
    end

    it "builds per-game missing lists including skipped rows" do
      gp = described_class.call(main).games.first
      expect(gp.left).to eq(1)
      expect(gp.skipped).to eq(1)
      expect(gp.first_earned_labels).to include(alt.label)
      expect(gp.missing.map { |m| [m.trophy, m.skipped] }).to eq([[t2, false], [t3, true]])
      expect(gp.missing.first.first_earned_label).to eq(alt.label)
    end
  end

  it "sorts incomplete games by fewest left, complete games last" do
    # Game A: alt earned 2, main re-earned 1 (left=1)
    game_a = create(:game, name: "Game A")
    a1 = create(:trophy, game: game_a)
    a2 = create(:trophy, game: game_a)
    create(:account_trophy, account: alt, trophy: a1, earned: true, earned_at: Time.zone.parse("2022-05-01 10:00"))
    create(:account_trophy, account: alt, trophy: a2, earned: true, earned_at: Time.zone.parse("2022-05-01 10:00"))
    create(:account_trophy, account: main, trophy: a1, earned: true, earned_at: Time.zone.parse("2024-03-14 21:47"))

    # Game B: alt earned 3, main re-earned 0 (left=3)
    game_b = create(:game, name: "Game B")
    b1 = create(:trophy, game: game_b)
    b2 = create(:trophy, game: game_b)
    b3 = create(:trophy, game: game_b)
    [b1, b2, b3].each { |t| create(:account_trophy, account: alt, trophy: t, earned: true, earned_at: Time.zone.parse("2022-05-01 10:00")) }

    # Game C: alt earned 1, main also earned it (left=0, complete)
    game_c = create(:game, name: "Game C")
    c1 = create(:trophy, game: game_c)
    create(:account_trophy, account: alt, trophy: c1, earned: true, earned_at: Time.zone.parse("2022-05-01 10:00"))
    create(:account_trophy, account: main, trophy: c1, earned: true, earned_at: Time.zone.parse("2024-03-14 21:47"))

    result = described_class.call(main)
    expect(result.games.map(&:game)).to eq([game_a, game_b, game_c])
  end

  context "with empty baseline" do
    let(:fresh_account) { create(:account, current: true) }

    it "returns zeroed result for an empty baseline" do
      result = described_class.call(fresh_account)
      expect(result.total).to eq(0)
      expect(result.percent).to eq(0.0)
      expect(result.games).to be_empty
    end
  end
end
