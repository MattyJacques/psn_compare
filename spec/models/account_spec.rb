require "rails_helper"

RSpec.describe Account do
  it "requires a unique label" do
    create(:account, label: "main")
    expect(build(:account, label: "main")).not_to be_valid
  end

  it "encrypts the refresh token" do
    account = create(:account, refresh_token: "secret-token")
    raw = ActiveRecord::Base.connection.select_value(
      "SELECT refresh_token FROM accounts WHERE id = #{account.id}"
    )
    expect(raw).not_to include("secret-token")
    expect(account.reload.refresh_token).to eq("secret-token")
  end

  describe ".current / #make_current!" do
    it "moves the current flag atomically between accounts" do
      a = create(:account, current: true)
      b = create(:account)
      b.make_current!
      expect(Account.current).to eq(b)
      expect(a.reload.current).to be(false)
    end

    it "returns nil when no account is current" do
      expect(Account.current).to be_nil
    end
  end
end
