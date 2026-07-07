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
      # Non-bare path: an existing account keeps @bare false so the flash
      # (rendered by layouts/alerts, not yet wired into the bare layout) shows.
      create(:account)
      allow(Accounts::Register).to receive(:call).and_raise(PSN::AuthenticationError, "rejected")
      post accounts_path, params: { account: { label: "Main", npsso: "bad" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("rejected")
    end

    it "shows the rejection message on the bare first-run page with zero accounts" do
      # Regression: the bare layout used to render no flash at all, so a
      # rejected NPSSO on the very first link attempt showed no visible error.
      allow(Accounts::Register).to receive(:call).and_raise(PSN::AuthenticationError, "rejected")
      post accounts_path, params: { account: { label: "Main", npsso: "bad" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("rejected")
    end
  end

  it "lists accounts with sync status and a reauth warning" do
    account = create(:account, label: "Main", online_id: "matty", needs_reauth: true)
    create(:sync_run, account:, kind: "trophies", status: "failed", error_message: "boom")
    get accounts_path
    expect(response.body).to include("Main", "NPSSO token expired", "boom")
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

  describe "redesigned index" do
    it "shows account cards with roles and the link panel" do
      create(:account, current: true, label: "Matty_Hunter")
      create(:account, label: "Matty_JPN", needs_reauth: true)
      get accounts_path
      expect(response.body).to include("2 linked")
      expect(response.body).to include("MAIN — re-earn target")
      expect(response.body).to include("Re-link now")
      expect(response.body).to include("Link a new account")
      expect(response.body).to include("Sync schedule")
    end
  end

  describe "first run" do
    it "renders the bare first-run page when no accounts exist" do
      get new_account_path
      expect(response.body).to include("Link your first PSN account")
      expect(response.body).not_to include("Dashboard") # no sidebar
    end

    it "redirects new to index once accounts exist" do
      create(:account)
      get new_account_path
      expect(response).to redirect_to(accounts_path)
    end
  end
end
