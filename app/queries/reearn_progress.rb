# The headline feature: baseline = every trophy ANY account has earned
# (exact trophy set only); progress = the subset the current account has
# earned. The current account's own history counts toward the baseline.
class ReearnProgress
  GameProgress = Data.define(:game, :total, :reearned) do
    def complete? = reearned >= total
    def percent = total.zero? ? 0 : (reearned * 100.0 / total).round
  end

  Result = Data.define(:total, :reearned, :games) do
    def percent = total.zero? ? 0 : (reearned * 100.0 / total).round
  end

  def self.call(current_account)
    baseline = AccountTrophy.where(earned: true).select(:trophy_id)
    current = AccountTrophy.where(account: current_account, earned: true).select(:trophy_id)

    per_game_total = Trophy.where(id: baseline).group(:game_id).count
    per_game_done = Trophy.where(id: baseline).where(id: current).group(:game_id).count

    games = Game.where(id: per_game_total.keys).order(:name).map do |game|
      GameProgress.new(game:, total: per_game_total.fetch(game.id),
                       reearned: per_game_done.fetch(game.id, 0))
    end.sort_by { |gp| [gp.complete? ? 1 : 0, gp.game.name.to_s.downcase] }

    Result.new(total: per_game_total.values.sum, reearned: per_game_done.values.sum, games:)
  end
end
