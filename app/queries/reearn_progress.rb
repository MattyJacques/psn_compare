# Baseline = every trophy ANY account has earned, minus skipped ("won't
# earn") trophies. Progress = the subset the main account has earned.
class ReearnProgress
  MissingTrophy = Data.define(:trophy, :first_earned_at, :first_earned_label, :skipped)

  GameProgress = Data.define(:game, :total, :reearned, :skipped, :first_earned_labels, :missing) do
    def left = total - reearned
    def complete? = left <= 0
    def percent = total.zero? ? 0 : (reearned * 100.0 / total).round
  end

  Result = Data.define(:total, :reearned, :skipped, :games) do
    def percent = total.zero? ? 0.0 : (reearned * 100.0 / total).round(1)
    def to_go = total - reearned
    def games_left = games.count { |gp| !gp.complete? }
  end

  def self.call(main) = new(main).call

  def initialize(main)
    @main = main
  end

  def call
    games = earned_rows.group_by { |at| at.trophy.game }.map { |game, rows| game_progress(game, rows) }
    games = games.sort_by { |gp| [gp.complete? ? 1 : 0, gp.left, gp.game.name.to_s.downcase] }
    Result.new(total: games.sum(&:total), reearned: games.sum(&:reearned),
               skipped: games.sum(&:skipped), games:)
  end

  private

  def earned_rows
    @earned_rows ||= AccountTrophy.where(earned: true).includes(:account, trophy: %i[game skip])
  end

  def game_progress(game, rows)
    by_trophy = rows.group_by(&:trophy)
    skipped_trophies, live = by_trophy.keys.partition(&:skipped?)
    reearned = live.count { |t| by_trophy[t].any? { |at| at.account_id == @main.id } }
    GameProgress.new(game:, total: live.size, reearned:, skipped: skipped_trophies.size,
                     first_earned_labels: first_earned_labels(rows),
                     missing: missing_list(by_trophy))
  end

  def first_earned_labels(rows)
    rows.reject { |at| at.account_id == @main.id }
        .sort_by { |at| at.earned_at || Time.current }
        .map { |at| at.account.label }.uniq
  end

  def missing_list(by_trophy)
    by_trophy.filter_map { |trophy, earners|
      next if !trophy.skipped? && earners.any? { |at| at.account_id == @main.id }

      first = earners.reject { |at| at.account_id == @main.id }.min_by { |at| at.earned_at || Time.current } || earners.first
      MissingTrophy.new(trophy:, first_earned_at: first&.earned_at,
                        first_earned_label: first&.account&.label, skipped: trophy.skipped?)
    }.sort_by { |m| [m.skipped ? 1 : 0, m.trophy.id] }
  end
end
