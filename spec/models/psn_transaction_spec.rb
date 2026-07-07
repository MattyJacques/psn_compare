require "rails_helper"

RSpec.describe PsnTransaction do
  it "is unique per account and PSN transaction id" do
    account = create(:account)
    create(:psn_transaction, account:, psn_transaction_id: "T1")
    expect(build(:psn_transaction, account:, psn_transaction_id: "T1")).not_to be_valid
  end

  it "filters by kind scopes" do
    account = create(:account)
    purchase = create(:psn_transaction, account:, kind: "purchase")
    refund = create(:psn_transaction, account:, kind: "refund")
    wallet = create(:psn_transaction, account:, kind: "wallet")
    expect(described_class.purchases).to eq([purchase])
    expect(described_class.refunds).to eq([refund])
    expect(described_class.wallet_funding).to eq([wallet])
  end

  it "supports addon and subscription kinds and a spend scope" do
    account = create(:account)
    %w[purchase addon subscription refund wallet].each_with_index do |kind, i|
      create(:psn_transaction, account:, kind:, psn_transaction_id: "k#{i}", amount_minor: 100)
    end
    expect(described_class.spend_kinds.count).to eq(3)
    expect(described_class.addons.count).to eq(1)
    expect(described_class.subscriptions.count).to eq(1)
  end
end
