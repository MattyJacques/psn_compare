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
end
