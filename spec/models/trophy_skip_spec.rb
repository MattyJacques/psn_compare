require "rails_helper"

RSpec.describe TrophySkip do
  it "is unique per trophy and marks the trophy skipped" do
    trophy = create(:trophy)
    described_class.create!(trophy:)
    expect(trophy.reload).to be_skipped
    expect { described_class.create!(trophy:) }.to raise_error(ActiveRecord::RecordInvalid)
  end
end
