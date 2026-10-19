# frozen_string_literal: true

class ReopeningsController < ApplicationController
  before_action :set_hunt
  before_action :require_organizer

  def create
    minutes = Integer(params[:minutes].to_s, 10, exception: false).to_i
    if @hunt.ended? && !@hunt.reopen!(minutes.minutes, by: cookies[:user_id])
      flash[:warning] = "Pick between 1 and #{Hunt::REOPEN_LIMIT.in_minutes.to_i} minutes"
    end
    redirect_to hunt_results_path(@hunt.code)
  end

  def update
    @hunt.add_reopened_time!(Hunt::REOPEN_EXTRA)
    redirect_to hunt_results_path(@hunt.code)
  end

  def destroy
    @hunt.close_reopened!
    redirect_to hunt_results_path(@hunt.code)
  end

  private

  def set_hunt
    @hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
  end

  def require_organizer
    head :forbidden unless @hunt.organizer?(cookies[:user_id])
  end
end
