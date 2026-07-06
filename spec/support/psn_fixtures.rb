# Builders for the gem's Data objects so service specs never touch the API.
module PsnFixtures
  def psn_trophy_title(np_communication_id: "NPWR11111_00", name: "Astro Bot", platform: "PS5",
                       progress: 40, earned: { bronze: 4, silver: 1, gold: 0, platinum: 0 },
                       defined: { bronze: 20, silver: 10, gold: 5, platinum: 1 },
                       last_updated: "2024-05-01T10:00:00Z")
    PSN::TrophyTitle.new(
      name:, np_communication_id:, np_service_name: "trophy2", platform:, progress:,
      earned_counts: earned, defined_counts: defined,
      raw: { "trophyTitleIconUrl" => "https://img.example/#{np_communication_id}.png",
             "lastUpdatedDateTime" => last_updated }
    )
  end

  def psn_trophy(id:, name: "Trophy #{id}", grade: :bronze, earned: false, earned_at: nil,
                 detail: "Do the thing", hidden: false)
    PSN::Trophy.new(id:, name:, detail:, grade:, hidden:, rarity: 12.5,
                    earned:, earned_at:,
                    raw: { "trophyIconUrl" => "https://img.example/t#{id}.png" })
  end

  def psn_trophy_summary(level: 300, counts: { bronze: 10, silver: 5, gold: 2, platinum: 1 })
    PSN::TrophySummary.new(level:, progress: 10, tier: 3, earned_counts: counts, raw: {})
  end

  def psn_entitlement(id: "ENT-1", name: "Astro Bot", type: "ps5_native_game",
                      platform: "PS5", acquired_at: Time.utc(2024, 1, 5),
                      product_id: "EP9000-PPSA01325_00-ASTROBOT0000000")
    PSN::Entitlement.new(id:, name:, type:, platform:, acquired_at:,
                         raw: { "product_id" => product_id })
  end

  def psn_transaction(transaction_id: "TXN-1", type: "PURCHASE", amount: 6999, currency: "GBP",
                      date: Time.utc(2024, 2, 1), description: "Astro Bot")
    PSN::Transaction.new(transaction_id:, date:, description:, amount:, currency:,
                         payment_method: "Visa", type:, raw: {})
  end
end

RSpec.configure { |c| c.include PsnFixtures }
