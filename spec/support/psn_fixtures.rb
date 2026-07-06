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
end

RSpec.configure { |c| c.include PsnFixtures }
