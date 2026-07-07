require "rails_helper"

RSpec.describe Sync::Entitlements do
  let(:account) { create(:account) }
  let(:client) { stub_psn_client }
  let(:store) { instance_double(PSN::Resources::Store) }

  before { allow(client).to receive(:store).and_return(store) }

  it "upserts entitlements with a best-effort kind" do
    allow(store).to receive(:entitlements).and_return([
      psn_entitlement(id: "E1", type: "ps5_native_game"),
      psn_entitlement(id: "E2", name: "Astro Bot DLC", type: "unified_addon", product_id: nil),
      psn_entitlement(id: "E3", name: "Some Avatar", type: "mystery_thing", product_id: nil)
    ].lazy)

    expect(described_class.call(account)).to eq(3)
    expect(account.entitlements.find_by!(entitlement_id: "E1"))
      .to have_attributes(kind: "game", name: "Astro Bot", platform: "PS5",
                          product_id: "EP9000-PPSA01325_00-ASTROBOT0000000",
                          raw_type: "ps5_native_game")
    expect(account.entitlements.find_by!(entitlement_id: "E2").kind).to eq("dlc")
    expect(account.entitlements.find_by!(entitlement_id: "E3").kind).to eq("other")
  end

  it "is idempotent" do
    allow(store).to receive(:entitlements).and_return([psn_entitlement].lazy, [psn_entitlement].lazy)
    described_class.call(account)
    described_class.call(account)
    expect(account.entitlements.count).to eq(1)
  end

  it "classifies types containing both game and addon substrings as dlc" do
    allow(store).to receive(:entitlements)
      .and_return([psn_entitlement(id: "E9", type: "GAME_ADDON", product_id: nil)].lazy)
    described_class.call(account)
    expect(account.entitlements.find_by!(entitlement_id: "E9").kind).to eq("dlc")
  end

  it "skips entitlements without an id instead of failing the sync" do
    allow(store).to receive(:entitlements)
      .and_return([psn_entitlement(id: nil), psn_entitlement(id: "E1")].lazy)
    expect(described_class.call(account)).to eq(1)
    expect(account.entitlements.pluck(:entitlement_id)).to eq(["E1"])
  end
end
