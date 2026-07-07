module DesignHelper
  GRADE_BORDER = { "platinum" => "border-plat", "gold" => "border-gold-t",
                   "silver" => "border-silver-t", "bronze" => "border-bronze-t" }.freeze
  GRADE_TEXT = { "platinum" => "text-plat", "gold" => "text-gold-t",
                 "silver" => "text-silver-t", "bronze" => "text-bronze-t" }.freeze

  def mono_date(time) = time ? time.strftime("%-d %b %Y") : "—"
  def mono_time(time) = time ? time.strftime("%H:%M") : ""

  # "Matty_Hunter" -> "MH"; single-word labels use the first two letters.
  def initials(label)
    parts = label.to_s.split(/[_\s]+/)
    (parts.size > 1 ? parts.first(2).map { |p| p[0] } : [ label.to_s[0], label.to_s[1] ]).join.upcase
  end

  def grade_border(trophy_type) = GRADE_BORDER.fetch(trophy_type, "border-line3")
  def grade_text(trophy_type) = GRADE_TEXT.fetch(trophy_type, "text-mute")

  def chip_classes(active)
    base = "inline-flex items-center gap-1 rounded-[20px] px-3.5 py-[7px] text-[13px] border"
    active ? "#{base} bg-navbg border-sel text-navink font-semibold"
           : "#{base} border-line text-mute hover:text-ink2 hover:border-line3"
  end

  def relative_sync(time)
    return "never" unless time

    mins = ((Time.current - time) / 60).round
    mins < 60 ? "#{mins} min ago" : "#{(mins / 60)} h ago"
  end
end
