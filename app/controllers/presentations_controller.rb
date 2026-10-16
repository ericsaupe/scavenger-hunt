# frozen_string_literal: true

class PresentationsController < ApplicationController
  before_action :set_hunt
  before_action :require_owner, except: :claim

  def remote
    @presentation = @hunt.presentation
    if @presentation.empty?
      flash[:warning] = "No submissions yet!"
      return redirect_to hunt_path(code: @hunt.code.upcase)
    end

    @submission = @presentation.current
    @presenter_mode = true
  end

  def update
    presentation = @hunt.presentation
    submission_id = if params[:direction].present?
      presentation.step_id(params[:direction])
    elsif presentation.submission_ids.include?(params[:submission_id].to_i)
      params[:submission_id].to_i
    end
    return head :unprocessable_content if submission_id.nil?

    @hunt.present!(submission_id)
    head :no_content
  end

  def playback
    command = params.dig(:playback, :action)
    return head :unprocessable_content unless Hunt::PLAYBACK_COMMANDS.include?(command)

    @hunt.playback!(command)
    head :no_content
  end

  def claim
    if @hunt.owner_password_matches?(params[:password])
      @hunt.update!(owner_id: cookies[:user_id])
      redirect_to hunt_presenter_remote_path(@hunt.code.upcase)
    else
      flash[:warning] = "Incorrect password"
      redirect_to hunt_presenter_path(@hunt.code.upcase)
    end
  end

  private

  def set_hunt
    @hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
  end

  def require_owner
    return if @hunt.owner?(cookies[:user_id])

    respond_to do |format|
      format.html do
        flash[:warning] = "Take the remote to control the presentation"
        redirect_to hunt_presenter_path(@hunt.code.upcase)
      end
      format.any { head :forbidden }
    end
  end
end
