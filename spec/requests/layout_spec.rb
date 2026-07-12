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

  # The stream source must be data-turbo-permanent: recreating it on every
  # Turbo visit races old-element unsubscribe against new-element subscribe
  # (same signed stream name = same cable identifier), which can kill the
  # server-side subscription and silently drop sync_status refreshes.
  it "keeps the sync_status stream element permanent across Turbo visits" do
    create(:account)
    get "/"
    expect(response.body).to match(/<turbo-cable-stream-source[^>]*id="sync-status-stream"/)
    expect(response.body).to match(/<turbo-cable-stream-source[^>]*data-turbo-permanent/)
  end
end
