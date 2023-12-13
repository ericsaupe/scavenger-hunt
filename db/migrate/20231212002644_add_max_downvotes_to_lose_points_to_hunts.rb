class AddMaxDownvotesToLosePointsToHunts < ActiveRecord::Migration[7.1]
  def change
    add_column :hunts, :max_downvotes_to_lose_points, :integer, null: true, default: nil
  end
end
