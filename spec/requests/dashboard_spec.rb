require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  it "shows the re-earn hero and account table" do
    main = create(:account, current: true, label: "Matty_Hunter", trophy_level: 512)
    alt = create(:account, label: "Matty_Legacy")
    game = create(:game)
    t = create(:trophy, game:)
    create(:account_trophy, account: alt, trophy: t, earned: true)

    get root_path
    expect(response.body).to include("Re-earned on Matty_Hunter")
    expect(response.body).to include("0.0") # hero percent
    expect(response.body).to include("Open checklist")
    expect(response.body).to include("UNIQUE TO ACCOUNT")
    expect(response.body).to include("Matty_Legacy")
  end

  it "redirects to first-run when no accounts exist" do
    get root_path
    expect(response).to redirect_to(new_account_path)
  end

  it "shows the expired-token banner and rate-limit toast" do
    account = create(:account, current: true, label: "Matty_JPN", needs_reauth: true)
    create(:sync_run, account:, kind: "trophies", status: "rate_limited",
           error_message: "429", completed_at: 1.minute.ago)
    get root_path
    expect(response.body).to include("stopped syncing")
    expect(response.body).to include("Re-link now")
    expect(response.body).to include("Rate limited by PSN")
  end

  it "shows first-sync progress cards while an initial sync runs" do
    account = create(:account, current: true, label: "Fresh", last_synced_at: nil)
    create(:sync_run, account:, kind: "trophies", status: "running", started_at: Time.current)
    get root_path
    expect(response.body).to include("Pulling your history")
    expect(response.body).to include("syncing")
  end
end
