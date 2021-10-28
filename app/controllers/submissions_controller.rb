# frozen_string_literal: true

class SubmissionsController < ApplicationController
  def create
    submission = Submission.new(submission_params)
    if submission.save
      respond_to do |format|
        format.html do
          flash[:success] = "Checked #{submission.item.name} off the list!"
          redirect_to hunt_team_path(submission.team.hunt.code, submission.team)
        end
        format.json { render json: submission }
      end
    else
      respond_to do |format|
        format.html do
          flash[:error] = "There was a problem with your submission: #{submission.errors.full_messages.to_sentence}"
          redirect_to hunt_team_path(submission.team.hunt.code, submission.team)
        end
        format.json { render json: { submission: submission, errors: submission.errors.full_messages }.to_json }
      end
    end
  end

  private

  def submission_params
    params.require(:submission).permit(:item_id, :team_id, :photo)
  end
end
