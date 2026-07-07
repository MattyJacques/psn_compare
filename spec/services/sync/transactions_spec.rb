require "rails_helper"

RSpec.describe Sync::Transactions do
  let(:account) { create(:account) }
  let(:client) { stub_psn_client }
  let(:store) { instance_double(PSN::Resources::Store) }

  before { allow(client).to receive(:store).and_return(store) }

  it "upserts transactions with mapped kinds" do
    allow(store).to receive(:transactions).and_return([
      psn_transaction(transaction_id: "T1", type: "PURCHASE"),
      psn_transaction(transaction_id: "T2", type: "REFUND", amount: -6999),
      psn_transaction(transaction_id: "T3", type: "WALLET_FUNDING", amount: 2500)
    ].lazy)

    expect(described_class.call(account)).to eq(3)
    expect(account.psn_transactions.find_by!(psn_transaction_id: "T1"))
      .to have_attributes(kind: "purchase", amount_minor: 6999, currency: "GBP",
                          description: "Astro Bot", occurred_at: Time.utc(2024, 2, 1))
    expect(account.psn_transactions.find_by!(psn_transaction_id: "T2").kind).to eq("refund")
    expect(account.psn_transactions.find_by!(psn_transaction_id: "T3").kind).to eq("wallet")
  end

  it "is idempotent" do
    allow(store).to receive(:transactions).and_return([psn_transaction].lazy, [psn_transaction].lazy)
    described_class.call(account)
    described_class.call(account)
    expect(account.psn_transactions.count).to eq(1)
  end
end
