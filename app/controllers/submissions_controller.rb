# frozen_string_literal: true

class SubmissionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:update]

  def update
    submission = Submission.find(params[:id])
    hunt = submission.hunt
    submission.assign_attributes(submission_params)

    if !hunt.accepts_photo_captured_at?(submission.captured_at)
      reject(submission, "The hunt ended before this photo was sent")
    elsif submission.save
      accept(submission)
    else
      reject(submission, submission.errors[:photo].first)
    end
  end

  def vote_menu
    @submission = Submission.find(params[:submission_id])
  end

  private

  def submission_params
    params.require(:submission).permit(:photo, :captured_at)
  end

  def accept(submission)
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

  def reject(submission, message)
    blob = submission.attachment_changes["photo"]&.blob
    blob.purge_later if blob&.persisted?
    submission.reload

    respond_to do |format|
      format.turbo_stream do
        render status: :unprocessable_content, turbo_stream: [
          turbo_stream.replace(submission, partial: "submissions/submission", locals: {submission:, animate: false}),
          turbo_stream.append(:flash, partial: "banners/banner", locals: {message:})
        ]
      end
      format.html do
        flash[:error] = message
        redirect_to hunt_team_path(submission.team.hunt.code, submission.team)
      end
    end
  end
end
