require "rails_helper"

RSpec.describe "Application shell", type: :request do
  it "renders the RE:EARN sidebar nav with design labels" do
    create(:account)
    get "/"
    expect(response.body).to include("RE:EARN")
    %w[Dashboard Trophies Checklist Library Purchases Accounts].each do |label|
      expect(response.body).to include(label)
    end
  end
end
