require "rails_helper"

RSpec.describe DesignHelper, type: :helper do
  it "formats dates and times in handoff style" do
    t = Time.zone.parse("2024-03-14 21:47")
    expect(helper.mono_date(t)).to eq("14 Mar 2024")
    expect(helper.mono_time(t)).to eq("21:47")
    expect(helper.mono_date(nil)).to eq("—")
  end

  it "builds initials from account labels" do
    expect(helper.initials("Matty_Hunter")).to eq("MH")
    expect(helper.initials("CoOpCouch")).to eq("CO")
    expect(helper.initials("Solo")).to eq("SO")
  end

  it "maps trophy grades to token classes" do
    expect(helper.grade_border("platinum")).to eq("border-plat")
    expect(helper.grade_text("gold")).to eq("text-gold-t")
    expect(helper.grade_border("unknown")).to eq("border-line3")
  end

  it "reports relative sync times" do
    expect(helper.relative_sync(nil)).to eq("never")
    expect(helper.relative_sync(12.minutes.ago)).to eq("12 min ago")
  end
end
