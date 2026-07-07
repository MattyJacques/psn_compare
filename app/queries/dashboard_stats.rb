class DashboardStats
  Stats = Data.define(:unique_counts, :closest, :biggest_gap, :not_owned_count, :progress)

  def self.call(main)
    progress = ReearnProgress.call(main)
    ownership = MainOwnership.call(main)
    incomplete = progress.games.reject(&:complete?)
    not_owned = incomplete.reject { |gp| ownership.owned?(gp.game) }

    Stats.new(unique_counts:, closest: incomplete.min_by(&:left),
              biggest_gap: incomplete.max_by(&:left),
              not_owned_count: not_owned.size, progress:)
  end

  # Trophies earned by exactly one account, counted per account.
  def self.unique_counts
    solo = AccountTrophy.where(earned: true).group(:trophy_id)
                        .having("COUNT(*) = 1").select(:trophy_id)
    AccountTrophy.where(earned: true, trophy_id: solo).group(:account_id).count
  end
end
