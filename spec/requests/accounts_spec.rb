require "rails_helper"

RSpec.describe "Accounts", type: :request do
  include ActiveJob::TestHelper

  describe "POST /accounts" do
    it "registers an account from an NPSSO and redirects" do
      account = build_stubbed(:account, label: "Main")
      allow(Accounts::Register).to receive(:call)
        .with(label: "Main", npsso: "np-token").and_return(account)
      post accounts_path, params: { account: { label: "Main", npsso: "np-token" } }
      expect(response).to redirect_to(accounts_path)
    end

    it "re-renders the form when the NPSSO is rejected" do
      allow(Accounts::Register).to receive(:call).and_raise(PSN::AuthenticationError, "rejected")
      post accounts_path, params: { account: { label: "Main", npsso: "bad" } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("rejected")
    end
  end

  it "lists accounts with sync status and a reauth warning" do
    account = create(:account, label: "Main", online_id: "matty", needs_reauth: true)
    create(:sync_run, account:, kind: "trophies", status: "failed", error_message: "boom")
    get accounts_path
    expect(response.body).to include("Main", "matty", "Needs re-authentication", "boom")
  end

  it "queues a sync" do
    account = create(:account)
    expect { post sync_account_path(account) }.to have_enqueued_job(SyncAccountJob).with(account)
    expect(response).to redirect_to(accounts_path)
  end

  it "switches the current account" do
    create(:account, current: true)
    account = create(:account)
    patch make_current_account_path(account)
    expect(Account.current).to eq(account)
  end

  it "reauthenticates with a fresh NPSSO" do
    account = create(:account, needs_reauth: true)
    allow(Account).to receive(:find).and_return(account)
    allow(account).to receive(:reauthenticate!)
    patch reauth_account_path(account), params: { npsso: "fresh" }
    expect(account).to have_received(:reauthenticate!).with("fresh")
    expect(response).to redirect_to(accounts_path)
  end
end
