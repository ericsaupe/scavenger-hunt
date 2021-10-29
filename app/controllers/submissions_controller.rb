# frozen_string_literal: true

class SubmissionsController < ApplicationController
  def update
    submission = Submission.find(params[:id])
    submission.update!(submission_params)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(:submissions, partial: 'submissions/submission',
                                                                locals: { submission: submission })
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
