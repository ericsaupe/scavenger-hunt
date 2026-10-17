# frozen_string_literal: true

class PresentationsController < ApplicationController
  before_action :set_hunt
  before_action :require_remote, except: :claim

  def remote
    @presentation = @hunt.presentation
    if @presentation.empty?
      flash[:warning] = "No submissions yet!"
      return redirect_to hunt_path(code: @hunt.code.upcase)
    end

    @slide = @presentation.current
    @presenter_mode = true
  end

  def update
    presentation = @hunt.presentation
    slide_key = if params[:direction].present?
      presentation.step_key(params[:direction])
    elsif presentation.include?(params[:slide])
      params[:slide]
    end
    return head :unprocessable_content if slide_key.nil?

    @hunt.present!(slide_key)
    head :no_content
  end

  def playback
    command = params.dig(:playback, :action)
    return head :unprocessable_content unless Hunt::PLAYBACK_COMMANDS.include?(command)

    @hunt.playback!(command)
    head :no_content
  end

  def screen_chat
    mode = params[:screen_chat]
    return head :unprocessable_content unless Hunt.screen_chats.key?(mode)

    @hunt.screen_chat!(mode)
    head :no_content
  end

  def claim
    if @hunt.owner_password_matches?(params[:password])
      @hunt.hand_remote_to!(cookies[:user_id])
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

  def require_remote
    return if @hunt.remote_holder?(cookies[:user_id])

    respond_to do |format|
      format.html do
        flash[:warning] = "Take the remote to control the presentation"
        redirect_to hunt_presenter_path(@hunt.code.upcase)
      end
      format.any { head :forbidden }
    end
  end
end
