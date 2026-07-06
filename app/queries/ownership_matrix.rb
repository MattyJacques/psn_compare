# Titles × accounts grid built from entitlements. In-memory grouping is fine
# at personal-library scale (a few thousand rows).
class OwnershipMatrix
  Row = Data.define(:name, :platform, :by_account_id) do
    def duplicate? = by_account_id.size > 1
  end

  def self.call(include_dlc: false)
    scope = include_dlc ? Entitlement.where(kind: %w[game dlc]) : Entitlement.games
    scope.group_by(&:product_key).map { |_, ents|
      Row.new(name: ents.first.name, platform: ents.first.platform,
              by_account_id: ents.index_by(&:account_id))
    }.sort_by { |row| row.name.to_s.downcase }
  end
end
