require "rails_helper"

RSpec.describe MainOwnership do
  let(:main) { create(:account, current: true) }

  it "owns games the main account has played" do
    game = create(:game)
    create(:account_game, account: main, game:)
    expect(described_class.call(main).owned?(game)).to be true
  end

  it "owns games matching a main entitlement name, ignoring punctuation and editions" do
    game = create(:game, name: "Elden Ring")
    create(:entitlement, account: main, kind: "game", name: "ELDEN RING: Deluxe Edition")
    expect(described_class.call(main).owned?(game)).to be true
  end

  it "does not own games only alts have" do
    game = create(:game)
    create(:account_game, account: create(:account), game:)
    expect(described_class.call(main).owned?(game)).to be false
  end

  it "owns nothing when there is no main account" do
    game = create(:game)
    expect(described_class.call(nil).owned?(game)).to be false
  end
end
