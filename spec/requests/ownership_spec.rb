require "rails_helper"

RSpec.describe "Ownership", type: :request do
  it "renders the matrix with duplicate highlighting" do
    a = create(:account, label: "Main")
    b = create(:account, label: "Alt")
    create(:entitlement, account: a, name: "Astro Bot", product_id: "EP-ASTRO")
    create(:entitlement, account: b, name: "Astro Bot", product_id: "EP-ASTRO")

    get ownership_index_path
    expect(response.body).to include("Astro Bot", "Main", "Alt", "Duplicate")
  end
end
