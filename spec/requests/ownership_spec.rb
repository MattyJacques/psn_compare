require "rails_helper"

RSpec.describe "Library", type: :request do
  it "renders the ownership matrix with legend and re-earn column" do
    main = create(:account, current: true, label: "Hunter")
    create(:entitlement, account: main, kind: "game", name: "Journey")
    get ownership_index_path
    expect(response.body).to include("across")
    expect(response.body).to include("To re-earn here")
    expect(response.body).to include("Journey")
    expect(response.body).to include("owned")
  end

  it "excludes a game played on main from the not_owned filter even if only an alt account has the entitlement" do
    main = create(:account, current: true, label: "Hunter")
    alt = create(:account, label: "Alt")
    game = create(:game, name: "Journey")
    create(:account_game, account: main, game:)
    create(:entitlement, account: alt, kind: "game", name: "Journey")

    get ownership_index_path(filter: "not_owned")

    expect(response.body).not_to include("Journey")
  end
end
