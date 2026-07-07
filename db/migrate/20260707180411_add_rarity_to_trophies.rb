class AddRarityToTrophies < ActiveRecord::Migration[8.1]
  def change
    add_column :trophies, :rarity_percent, :decimal, precision: 5, scale: 2
  end
end
