module Sync
  # Pulls every trophy title for the account, then the per-trophy earned
  # state for titles that changed since the last sync.
  class Trophies
    def self.call(account) = new(account).call

    def initialize(account)
      @account = account
    end

    def call
      count = 0
      @account.with_client do |client|
        client.trophies.titles.each do |title|
          sync_title(client, title)
          count += 1
        end
        update_account_summary(client)
      end
      count
    end

    private

    def sync_title(client, title)
      game = upsert_game(title)
      account_game = @account.account_games.find_or_initialize_by(game:)
      last_played = Time.iso8601(title.raw["lastUpdatedDateTime"]) if title.raw["lastUpdatedDateTime"]
      return if unchanged?(account_game, title, last_played)

      ApplicationRecord.transaction do
        account_game.update!(progress: title.progress, last_played_at: last_played,
                             **counts(:earned, title.earned_counts))
        sync_trophies(client, game, title)
      end
    end

    def unchanged?(account_game, title, last_played)
      account_game.persisted? && account_game.progress == title.progress &&
        account_game.last_played_at == last_played
    end

    def upsert_game(title)
      game = Game.find_or_initialize_by(np_communication_id: title.np_communication_id)
      game.update!(name: title.name, platform: title.platform,
                   icon_url: title.raw["trophyTitleIconUrl"],
                   **counts(:total, title.defined_counts))
      game
    end

    def sync_trophies(client, game, title)
      client.trophies.earned(np_communication_id: game.np_communication_id,
                             platform: title.platform).each do |psn_trophy|
        trophy = game.trophies.find_or_initialize_by(psn_trophy_id: psn_trophy.id)
        trophy.update!(trophy_type: psn_trophy.grade.to_s, name: psn_trophy.name,
                       detail: psn_trophy.detail, hidden: psn_trophy.hidden,
                       icon_url: psn_trophy.raw["trophyIconUrl"])
        @account.account_trophies.find_or_initialize_by(trophy:)
                .update!(earned: psn_trophy.earned?, earned_at: psn_trophy.earned_at)
      end
    end

    def update_account_summary(client)
      summary = client.trophies.summary
      @account.update!(trophy_level: summary.level, last_synced_at: Time.current,
                       **counts(:earned, summary.earned_counts))
    end

    # {bronze: 1, ...} -> {earned_bronze: 1, ...} / {total_bronze: 1, ...}
    def counts(prefix, grade_counts)
      (grade_counts || {}).transform_keys { |grade| :"#{prefix}_#{grade}" }
    end
  end
end
