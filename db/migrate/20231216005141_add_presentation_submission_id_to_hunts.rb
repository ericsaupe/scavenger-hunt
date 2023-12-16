class AddPresentationSubmissionIdToHunts < ActiveRecord::Migration[7.1]
  def change
    add_column :hunts, :presentation_submission_id, :integer
  end
end
