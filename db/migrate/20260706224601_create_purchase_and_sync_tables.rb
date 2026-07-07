class CreatePurchaseAndSyncTables < ActiveRecord::Migration[8.1]
  def change
    create_table :entitlements do |t|
      t.references :account, null: false, foreign_key: true
      t.string :entitlement_id, null: false
      t.string :product_id
      t.string :name
      t.string :kind, null: false, default: "other"
      t.string :raw_type
      t.string :platform
      t.datetime :acquired_at
      t.timestamps
      t.index [ :account_id, :entitlement_id ], unique: true
      t.index :product_id
    end

    create_table :psn_transactions do |t|
      t.references :account, null: false, foreign_key: true
      t.string :psn_transaction_id, null: false
      t.string :kind, null: false, default: "purchase"
      t.integer :amount_minor
      t.string :currency
      t.datetime :occurred_at
      t.text :description
      t.string :payment_method
      t.timestamps
      t.index [ :account_id, :psn_transaction_id ], unique: true
    end

    create_table :sync_runs do |t|
      t.references :account, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "running"
      t.integer :items_synced, null: false, default: 0
      t.text :error_message
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps
      t.index [ :account_id, :kind, :created_at ]
    end
  end
end
