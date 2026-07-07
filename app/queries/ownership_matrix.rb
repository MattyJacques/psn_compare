# Titles × accounts grid built from entitlements. In-memory grouping is fine
# at personal-library scale (a few thousand rows).
class OwnershipMatrix
  Row = Data.define(:name, :platform, :by_account_id, :reearn_count) do
    def duplicate? = by_account_id.size > 1
  end

  def self.call(include_dlc: false, main: nil)
    counts = main ? candidate_counts(main) : {}
    scope = include_dlc ? Entitlement.where(kind: %w[game dlc]) : Entitlement.games
    scope.group_by(&:product_key).map { |_, ents|
      name = ents.first.name
      Row.new(name:, platform: ents.first.platform,
              by_account_id: ents.index_by(&:account_id),
              reearn_count: count_for(counts, MainOwnership.normalize(name)))
    }.sort_by { |row| row.name.to_s.downcase }
  end

  # {normalized game name => number of unskipped missing-on-main trophies}
  def self.candidate_counts(main)
    ReearnProgress.call(main).games.each_with_object({}) do |gp, acc|
      count = gp.missing.count { |m| !m.skipped }
      acc[MainOwnership.normalize(gp.game.name)] = count if count.positive?
    end
  end

  def self.count_for(counts, norm)
    counts[norm] || counts.find { |k, _| norm.start_with?(k) }&.last
  end
  private_class_method :count_for
end
