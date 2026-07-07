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
end
