module Sync
  class Entitlements
    # The entitlements endpoint is undocumented; classify types defensively
    # and keep the raw type so misclassifications are diagnosable.
    # Check DLC types first (more specific substrings) before game types.
    DLC_TYPES = /addon|add_on|dlc|expansion|season_pass/i
    GAME_TYPES = /game|full_game|title/i

    def self.call(account) = new(account).call

    def initialize(account)
      @account = account
    end

    def call
      count = 0
      @account.with_client do |client|
        client.store.entitlements.each do |ent|
          next if ent.id.blank?
          @account.entitlements.find_or_initialize_by(entitlement_id: ent.id)
                  .update!(name: ent.name, kind: kind_for(ent.type), raw_type: ent.type,
                           platform: ent.platform, acquired_at: ent.acquired_at,
                           product_id: ent.raw["product_id"])
          count += 1
        end
      end
      count
    end

    private

    def kind_for(type)
      case type
      when DLC_TYPES then "dlc"
      when GAME_TYPES then "game"
      else "other"
      end
    end
  end
end
