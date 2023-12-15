class AddPasswordEnteredForLeaderboardToHunts < ActiveRecord::Migration[7.1]
  def change
    add_column :hunts, :password_entered_for_leaderboard, :boolean, default: false, null: false
  end
end
