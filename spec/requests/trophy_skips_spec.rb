require "rails_helper"

RSpec.describe "Trophy skips", type: :request do
  it "creates and removes a skip, redirecting back" do
    trophy = create(:trophy)
    post trophy_skip_path(trophy), headers: { "HTTP_REFERER" => reearn_path }
    expect(response).to redirect_to(reearn_path)
    expect(trophy.reload).to be_skipped

    delete trophy_skip_path(trophy), headers: { "HTTP_REFERER" => reearn_path }
    expect(trophy.reload).not_to be_skipped
  end
end
