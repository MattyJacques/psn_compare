module Accounts
  class Register
    def self.call(label:, npsso:)
      client = PSN::Client.new(npsso: npsso)
      profile = client.profiles.find
      Account.create!(
        label: label,
        online_id: profile.online_id,
        psn_account_id: profile.account_id,
        trophy_level: profile.trophy_summary&.level,
        refresh_token: client.refresh_token,
        current: !Account.exists?(current: true)
      )
    end
  end
end
