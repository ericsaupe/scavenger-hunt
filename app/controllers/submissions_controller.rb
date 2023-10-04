# frozen_string_literal: true

class SubmissionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:update]

  def update
    submission = Submission.find(params[:id])

    if submission.hunt.ended?
      # If the hunt is ended, let's just touch it to get an updated object
      submission.touch # rubocop:disable Rails/SkipsModelValidations
    else
      submission.update!(submission_params)
    end

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(:submissions, partial: "submissions/submission",
          locals: {submission:})
      end
      format.js
      format.html do
        flash[:success] = "Checked #{submission.item.name} off the list!"
        redirect_to hunt_team_path(submission.team.hunt.code, submission.team)
      end
    end
  end

  private

  def submission_params
    params.require(:submission).permit(:item_id, :team_id, :photo)
  end
end
