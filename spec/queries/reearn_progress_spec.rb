require "rails_helper"

RSpec.describe ReearnProgress do
  let(:main) { create(:account, current: true) }
  let(:alt) { create(:account) }
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
