# A purchase is a "2nd copy" when its item name matches a game entitlement
# that lives on a different account — i.e. the game was bought again for
# the re-earn run. Name matching is normalized-exact; personal-library
# scale, so in-memory is fine.
class SecondCopies
  def self.transaction_ids
    owners = Entitlement.games.pluck(:name, :account_id)
                        .group_by { |name, _| MainOwnership.normalize(name) }
                        .transform_values { |pairs| pairs.map(&:last).to_set }
    PsnTransaction.purchases.pluck(:id, :description, :account_id).filter_map { |id, desc, account_id|
      other = owners[MainOwnership.normalize(desc)]
      id if other && (other - [account_id]).any?
    }.to_set
  end
end
