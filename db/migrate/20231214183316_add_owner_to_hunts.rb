class AddOwnerToHunts < ActiveRecord::Migration[7.1]
  def change
    add_column :hunts, :owner_id, :string, null: true
    add_index :hunts, :owner_id
  end
end
