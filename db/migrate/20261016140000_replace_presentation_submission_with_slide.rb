# frozen_string_literal: true

class ReplacePresentationSubmissionWithSlide < ActiveRecord::Migration[8.1]
  def up
    add_column :hunts, :presentation_slide, :string
    execute <<~SQL.squish
      UPDATE hunts SET presentation_slide = 'submission:' || presentation_submission_id
      WHERE presentation_submission_id IS NOT NULL
    SQL
    remove_column :hunts, :presentation_submission_id
  end

  def down
    add_column :hunts, :presentation_submission_id, :integer
    execute <<~SQL.squish
      UPDATE hunts SET presentation_submission_id = SUBSTRING(presentation_slide FROM 12)::integer
      WHERE presentation_slide LIKE 'submission:%'
    SQL
    remove_column :hunts, :presentation_slide
  end
end
