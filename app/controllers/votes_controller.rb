class VotesController < ApplicationController
  def create
    vote = submission.votes.find_or_initialize_by(user_id: vote_params[:user_id])
    if vote.value == vote_params[:value]
      vote.value = nil
    else
      vote.attributes = vote_params
    end
    vote.save!
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
    params.require(:vote).permit(:value).merge(user_id: cookies[:user_id])
  end

  def submission
    @submission ||= Submission.find(params[:submission_id])
  end
end
