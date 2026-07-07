# One flat ranked list of every re-earn candidate across all games.
class ReearnBacklog
  Row = Data.define(:trophy, :game, :first_earned_at, :first_earned_label, :rarity, :owned_on_main)

  def self.call(main, sort: "common", filter: nil) = new(main, sort:, filter:).call

  def initialize(main, sort:, filter:)
    @main, @sort, @filter = main, sort, filter
  end

  def call
    rows = candidate_trophies.map { |trophy, earners| build_row(trophy, earners) }
    rows = apply_filter(rows)
    sorted(rows)
  end

  private

  def candidate_trophies
    earned = AccountTrophy.where(earned: true).includes(:account, trophy: %i[game skip])
    by_trophy = earned.group_by(&:trophy)
    if @filter == "skipped"
      by_trophy.select { |t, _| t.skipped? }
    else
      by_trophy.reject { |t, earners| t.skipped? || earners.any? { |at| at.account_id == @main.id } }
    end
  end

  def build_row(trophy, earners)
    first = earners.reject { |at| at.account_id == @main.id }.min_by { |at| at.earned_at || Time.current } || earners.first
    Row.new(trophy:, game: trophy.game, first_earned_at: first&.earned_at,
            first_earned_label: first&.account&.label,
            rarity: trophy.rarity_percent&.to_f,
            owned_on_main: ownership.owned?(trophy.game))
  end

  def ownership = @ownership ||= MainOwnership.call(@main)

  def apply_filter(rows)
    case @filter
    when "platinum" then rows.select { |r| r.trophy.trophy_type == "platinum" }
    when "owned" then rows.select(&:owned_on_main)
    else rows
    end
  end

  def sorted(rows)
    if @sort == "rare"
      rows.sort_by { |r| [ r.rarity ? 0 : 1, r.rarity || 0 ] }
    else
      rows.sort_by { |r| [ r.rarity ? 0 : 1, -(r.rarity || 0) ] }
    end
  end
end
