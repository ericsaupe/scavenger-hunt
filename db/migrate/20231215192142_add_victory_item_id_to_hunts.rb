class AddVictoryItemIdToHunts < ActiveRecord::Migration[7.1]
  def change
    add_column :hunts, :victory_item_id, :integer
  end
end
