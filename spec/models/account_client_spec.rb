require "rails_helper"

RSpec.describe Account, "#with_client" do
  let(:account) { create(:account, refresh_token: "old-token") }

  it "yields a client built from the stored refresh token and persists rotation" do
    client = stub_psn_client(refresh_token: "new-token")
    result = account.with_client { |c| expect(c).to be(client); :done }
    expect(PSN::Client).to have_received(:new).with(refresh_token: "old-token")
    expect(result).to eq(:done)
    expect(account.reload.refresh_token).to eq("new-token")
  end

  it "flags needs_reauth and re-raises on authentication failure" do
    stub_psn_client
    expect {
      account.with_client { raise PSN::AuthenticationError, "expired" }
    }.to raise_error(PSN::AuthenticationError)
    expect(account.reload.needs_reauth).to be(true)
  end

  it "reauthenticate! stores a new token and clears the flag" do
    account.update!(needs_reauth: true)
    client = stub_psn_client(refresh_token: "brand-new")
    allow(client).to receive(:access_token).and_return("jwt")
    account.reauthenticate!("fresh-npsso")
    expect(PSN::Client).to have_received(:new).with(npsso: "fresh-npsso")
    expect(account.reload).to have_attributes(refresh_token: "brand-new", needs_reauth: false)
  end
end
