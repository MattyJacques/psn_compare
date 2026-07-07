require "rails_helper"

RSpec.describe Accounts::Register do
  let(:profile) do
    PSN::Profile.new(online_id: "matty", account_id: "123456789", avatar_url: nil,
                     plus: true, about_me: nil, languages: nil, verified: false,
                     trophy_summary: PSN::TrophySummary.new(level: 420, progress: 50, tier: nil,
                                                            earned_counts: { bronze: 100, silver: 50,
                                                                             gold: 20, platinum: 5 },
                                                            raw: {}),
                     online: false, platform: nil, last_online_at: nil, raw: {})
  end

  let(:profile2) do
    PSN::Profile.new(online_id: "matty2", account_id: "987654321", avatar_url: nil,
                     plus: true, about_me: nil, languages: nil, verified: false,
                     trophy_summary: PSN::TrophySummary.new(level: 420, progress: 50, tier: nil,
                                                            earned_counts: { bronze: 100, silver: 50,
                                                                             gold: 20, platinum: 5 },
                                                            raw: {}),
                     online: false, platform: nil, last_online_at: nil, raw: {})
  end

  before do
    client = stub_psn_client(refresh_token: "fresh-refresh-token")
    profiles = instance_double(PSN::Resources::Profiles, find: profile)
    allow(client).to receive(:profiles).and_return(profiles)
  end

  it "creates an account from an NPSSO token" do
    profile_with_avatar = PSN::Profile.new(online_id: "matty", account_id: "123456789",
                                           avatar_url: "https://example.com/avatar.jpg",
                                           plus: true, about_me: nil, languages: nil,
                                           verified: false,
                                           trophy_summary: PSN::TrophySummary.new(level: 420, progress: 50, tier: nil,
                                                                                  earned_counts: { bronze: 100, silver: 50,
                                                                                                   gold: 20, platinum: 5 },
                                                                                  raw: {}),
                                           online: false, platform: nil, last_online_at: nil, raw: {})
    client = stub_psn_client(refresh_token: "fresh-refresh-token")
    profiles = instance_double(PSN::Resources::Profiles, find: profile_with_avatar)
    allow(client).to receive(:profiles).and_return(profiles)

    account = described_class.call(label: "Main", npsso: "npsso-value")
    expect(PSN::Client).to have_received(:new).with(npsso: "npsso-value")
    expect(account).to have_attributes(label: "Main", online_id: "matty",
                                       psn_account_id: "123456789", trophy_level: 420,
                                       refresh_token: "fresh-refresh-token",
                                       avatar_url: "https://example.com/avatar.jpg")
  end

  it "makes the first account current, but not later ones" do
    client1 = stub_psn_client(refresh_token: "fresh-refresh-token")
    profiles1 = instance_double(PSN::Resources::Profiles, find: profile)
    allow(client1).to receive(:profiles).and_return(profiles1)

    first = described_class.call(label: "One", npsso: "n")

    client2 = stub_psn_client(refresh_token: "fresh-refresh-token")
    profiles2 = instance_double(PSN::Resources::Profiles, find: profile2)
    allow(client2).to receive(:profiles).and_return(profiles2)

    second = described_class.call(label: "Two", npsso: "n")
    expect(first.reload).to be_current
    expect(second).not_to be_current
  end
end
