class VotesController < ApplicationController
  def create
    vote = submission.votes.find_by(user_id:) || submission.votes.create_or_find_by!(user_id:)
    vote.update!(value: (vote.value == vote_params[:value]) ? nil : vote_params[:value])
    submission.calculate_denied_points
    submission.hunt.presentation.broadcast_reaction(vote)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("submission_vote_#{[vote.user_id, vote.submission_id].join("_")}",
          partial: "items/vote_menu",
          locals: {vote:})
      end
    end
  end

  private

  def vote_params
    params.require(:vote).permit(:value)
  end

  def user_id
    cookies[:user_id]
  end

  def submission
    @submission ||= Submission.find(params[:submission_id])
  end
end
