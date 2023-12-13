class AddDeniedPointsToSubmission < ActiveRecord::Migration[7.1]
  def change
    add_column :submissions, :denied_points, :boolean, null: false, default: false
  end
end
