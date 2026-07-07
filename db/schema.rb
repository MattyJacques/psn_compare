# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_07_180415) do
  create_table "account_games", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.integer "earned_bronze", default: 0, null: false
    t.integer "earned_gold", default: 0, null: false
    t.integer "earned_platinum", default: 0, null: false
    t.integer "earned_silver", default: 0, null: false
    t.integer "game_id", null: false
    t.datetime "last_played_at"
    t.integer "progress", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "game_id"], name: "index_account_games_on_account_id_and_game_id", unique: true
    t.index ["account_id"], name: "index_account_games_on_account_id"
    t.index ["game_id"], name: "index_account_games_on_game_id"
  end

  create_table "account_trophies", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "created_at", null: false
    t.boolean "earned", default: false, null: false
    t.datetime "earned_at"
    t.integer "trophy_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "trophy_id"], name: "index_account_trophies_on_account_id_and_trophy_id", unique: true
    t.index ["account_id"], name: "index_account_trophies_on_account_id"
    t.index ["trophy_id"], name: "index_account_trophies_on_trophy_id"
  end

  create_table "accounts", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.boolean "current", default: false, null: false
    t.integer "earned_bronze", default: 0, null: false
    t.integer "earned_gold", default: 0, null: false
    t.integer "earned_platinum", default: 0, null: false
    t.integer "earned_silver", default: 0, null: false
    t.string "label", null: false
    t.datetime "last_synced_at"
    t.boolean "needs_reauth", default: false, null: false
    t.string "online_id"
    t.string "psn_account_id"
    t.text "refresh_token"
    t.integer "trophy_level"
    t.datetime "updated_at", null: false
    t.index ["label"], name: "index_accounts_on_label", unique: true
    t.index ["psn_account_id"], name: "index_accounts_on_psn_account_id", unique: true
  end

  create_table "entitlements", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "acquired_at"
    t.datetime "created_at", null: false
    t.string "entitlement_id", null: false
    t.string "kind", default: "other", null: false
    t.string "name"
    t.string "platform"
    t.string "product_id"
    t.string "raw_type"
    t.datetime "updated_at", null: false
    t.index ["account_id", "entitlement_id"], name: "index_entitlements_on_account_id_and_entitlement_id", unique: true
    t.index ["account_id"], name: "index_entitlements_on_account_id"
    t.index ["product_id"], name: "index_entitlements_on_product_id"
  end

  create_table "games", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "icon_url"
    t.string "name", null: false
    t.string "np_communication_id", null: false
    t.string "platform"
    t.integer "total_bronze", default: 0, null: false
    t.integer "total_gold", default: 0, null: false
    t.integer "total_platinum", default: 0, null: false
    t.integer "total_silver", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["np_communication_id"], name: "index_games_on_np_communication_id", unique: true
  end

  create_table "psn_transactions", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "amount_minor"
    t.datetime "created_at", null: false
    t.string "currency"
    t.text "description"
    t.string "kind", default: "purchase", null: false
    t.datetime "occurred_at"
    t.string "payment_method"
    t.string "psn_transaction_id", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "psn_transaction_id"], name: "index_psn_transactions_on_account_id_and_psn_transaction_id", unique: true
    t.index ["account_id"], name: "index_psn_transactions_on_account_id"
  end

  create_table "sync_runs", force: :cascade do |t|
    t.integer "account_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "items_synced", default: 0, null: false
    t.string "kind", null: false
    t.datetime "started_at"
    t.string "status", default: "running", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "kind", "created_at"], name: "index_sync_runs_on_account_id_and_kind_and_created_at"
    t.index ["account_id"], name: "index_sync_runs_on_account_id"
  end

  create_table "trophies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "detail"
    t.integer "game_id", null: false
    t.boolean "hidden", default: false, null: false
    t.string "icon_url"
    t.string "name"
    t.integer "psn_trophy_id", null: false
    t.decimal "rarity_percent", precision: 5, scale: 2
    t.string "trophy_type", null: false
    t.datetime "updated_at", null: false
    t.index ["game_id", "psn_trophy_id"], name: "index_trophies_on_game_id_and_psn_trophy_id", unique: true
    t.index ["game_id"], name: "index_trophies_on_game_id"
  end

  create_table "trophy_skips", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "note"
    t.integer "trophy_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trophy_id"], name: "index_trophy_skips_on_trophy_id", unique: true
  end

  add_foreign_key "account_games", "accounts"
  add_foreign_key "account_games", "games"
  add_foreign_key "account_trophies", "accounts"
  add_foreign_key "account_trophies", "trophies"
  add_foreign_key "entitlements", "accounts"
  add_foreign_key "psn_transactions", "accounts"
  add_foreign_key "sync_runs", "accounts"
  add_foreign_key "trophies", "games"
  add_foreign_key "trophy_skips", "trophies"
end
