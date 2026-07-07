require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#format_money" do
    it { expect(helper.format_money(6999, "GBP")).to eq("£69.99") }
    it { expect(helper.format_money(1250, "USD")).to eq("$12.50") }
    it { expect(helper.format_money(1250, "SEK")).to eq("12.50 SEK") }
    it { expect(helper.format_money(nil, "GBP")).to eq("—") }
    it { expect(helper.format_money(-100, "GBP")).to eq("-£1.00") }
    it { expect(helper.format_money(-1250, "SEK")).to eq("-12.50 SEK") }
  end
end
