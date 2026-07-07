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

  factory :entitlement do
    account
    sequence(:entitlement_id) { |n| "ENT-#{n}" }
    sequence(:product_id) { |n| "EP9000-CUSA%05d_00" % n }
    sequence(:name) { |n| "Product #{n}" }
    kind { "game" }
    platform { "PS5" }
    acquired_at { Time.zone.local(2021, 6, 1) }
  end

  factory :psn_transaction do
    account
    sequence(:psn_transaction_id) { |n| "TXN-#{n}" }
    kind { "purchase" }
    amount_minor { 6999 }
    currency { "GBP" }
    occurred_at { Time.zone.local(2021, 6, 1) }
    description { "A game" }
  end

  factory :sync_run do
    account
    kind { "trophies" }
    status { "succeeded" }
    started_at { 5.minutes.ago }
    completed_at { 1.minute.ago }
  end

  factory :trophy_skip do
    trophy
  end
end
