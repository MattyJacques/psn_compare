class CreateCoreTrophyTables < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :label, null: false, index: { unique: true }
      t.string :online_id
      t.string :psn_account_id, index: { unique: true }
      t.text :refresh_token
      t.boolean :current, null: false, default: false
      t.boolean :needs_reauth, null: false, default: false
      t.integer :trophy_level
      t.integer :earned_bronze, null: false, default: 0
      t.integer :earned_silver, null: false, default: 0
      t.integer :earned_gold, null: false, default: 0
      t.integer :earned_platinum, null: false, default: 0
      t.datetime :last_synced_at
      t.timestamps
    end

    create_table :games do |t|
      t.string :np_communication_id, null: false, index: { unique: true }
      t.string :name, null: false
      t.string :platform
      t.string :icon_url
      t.integer :total_bronze, null: false, default: 0
      t.integer :total_silver, null: false, default: 0
      t.integer :total_gold, null: false, default: 0
      t.integer :total_platinum, null: false, default: 0
      t.timestamps
    end

    create_table :trophies do |t|
      t.references :game, null: false, foreign_key: true
      t.integer :psn_trophy_id, null: false
      t.string :trophy_type, null: false
      t.string :name
      t.text :detail
      t.boolean :hidden, null: false, default: false
      t.string :icon_url
      t.timestamps
      t.index [:game_id, :psn_trophy_id], unique: true
    end

    create_table :account_games do |t|
      t.references :account, null: false, foreign_key: true
      t.references :game, null: false, foreign_key: true
      t.integer :progress, null: false, default: 0
      t.integer :earned_bronze, null: false, default: 0
      t.integer :earned_silver, null: false, default: 0
      t.integer :earned_gold, null: false, default: 0
      t.integer :earned_platinum, null: false, default: 0
      t.datetime :last_played_at
      t.timestamps
      t.index [:account_id, :game_id], unique: true
    end

    create_table :account_trophies do |t|
      t.references :account, null: false, foreign_key: true
      t.references :trophy, null: false, foreign_key: true
      t.boolean :earned, null: false, default: false
      t.datetime :earned_at
      t.timestamps
      t.index [:account_id, :trophy_id], unique: true
    end
  end
end
