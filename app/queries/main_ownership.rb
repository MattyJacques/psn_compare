# "Owned on main" heuristic: the game is on the main account's trophy list,
# or a main game entitlement's name matches the game name (normalized
# prefix match — entitlements carry edition suffixes).
class MainOwnership
  def self.call(main) = new(main)

  def self.normalize(name)
    name.to_s.downcase.gsub(/[^a-z0-9 ]/, " ").squeeze(" ").strip
  end

  def initialize(main)
    @main = main
    @played_game_ids = main ? main.account_games.pluck(:game_id).to_set : Set.new
    @entitlement_names = main ? main.entitlements.games.pluck(:name).map { |n| self.class.normalize(n) } : []
  end

  def owned?(game)
    return true if @played_game_ids.include?(game.id)

    key = self.class.normalize(game.name)
    key.present? && @entitlement_names.any? { |n| n.start_with?(key) }
  end
end
