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
end
