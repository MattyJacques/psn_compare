FactoryBot.define do
  factory :account do
    sequence(:label) { |n| "account-#{n}" }
    sequence(:online_id) { |n| "player#{n}" }
    sequence(:psn_account_id) { |n| (1_000_000 + n).to_s }
    refresh_token { "refresh-token" }
  end

  factory :game do
    sequence(:np_communication_id) { |n| format("NPWR%05d_00", n) }
    sequence(:name) { |n| "Game #{n}" }
    platform { "PS5" }
    total_bronze { 10 }
    total_silver { 5 }
    total_gold { 2 }
    total_platinum { 1 }
  end

  factory :trophy do
    game
    sequence(:psn_trophy_id) { |n| n }
    trophy_type { "bronze" }
    sequence(:name) { |n| "Trophy #{n}" }
  end

  factory :account_game do
    account
    game
    progress { 50 }
  end

  factory :account_trophy do
    account
    trophy
    earned { true }
    earned_at { Time.zone.local(2020, 1, 1) }
  end
end
