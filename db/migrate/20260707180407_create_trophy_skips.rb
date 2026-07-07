class CreateTrophySkips < ActiveRecord::Migration[8.1]
  def change
    create_table :trophy_skips do |t|
      t.references :trophy, null: false, foreign_key: true, index: { unique: true }
      t.text :note

      t.timestamps
    end
  end
end
