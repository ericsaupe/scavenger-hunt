# frozen_string_literal: true

class HuntsController < ApplicationController
  caches_action :index, expires_in: 1.day

  def index
    @templates = Templater.templates.sort_by(&:name)
    @popular_templates = Templater.popular_templates
  end

  def show
    @hunt = Hunt.find_by!(code: params[:code].upcase)
  end

  def new
    @hunt = Hunt.new(name: params[:template])
  end

  def create
    clean_params = hunt_params
    # timezones, man
    if clean_params[:timezone].present?
      timezone = clean_params.delete(:timezone)
      clean_params[:starts_at] = clean_params[:starts_at].in_time_zone(timezone)
      clean_params[:ends_at] = clean_params[:ends_at].in_time_zone(timezone)
    end
    @hunt = Templater.create_hunt!(clean_params.delete(:template))
    @hunt.update(clean_params)
    redirect_to hunt_path(code: @hunt.code.upcase)
  end

  def join
    return if params[:code].blank?

    hunt = Hunt.find_by(code: params[:code].upcase)
    if hunt
      redirect_to hunt_path(code: hunt.code.upcase)
    else
      flash.now[:error] = "A scavenger hunt was not found for that code, sorry!"
    end
  end

  def results
    @hunt = Hunt.includes(items: {submissions: :photo_attachment}).find_by!(code: params[:hunt_code].upcase)
    @results = @hunt.results
  end

  def download_results
    @hunt = Hunt.find_by!(code: params[:code].upcase)
    return head :forbidden if @hunt.results_locked?

    @hunt.refresh_archive
    redirect_to rails_blob_path(@hunt.archive, disposition: "attachment")
  end

  def unlock_leaderboard
    @hunt = Hunt.find_by!(code: params[:code].upcase)
    if @hunt.password == params[:password]
      @hunt.update(password_entered_for_leaderboard: true)
      flash.now[:success] = "Leaderboard unlocked!"
    else
      flash[:warning] = "Incorrect password"
    end
    redirect_to hunt_results_path(hunt_code: @hunt.code.upcase)
  end

  def unlock_results
    @hunt = Hunt.find_by!(code: params[:code].upcase)
    if @hunt.password == params[:password]
      @hunt.update(password_entered: true)
      flash.now[:success] = "Results unlocked!"
    else
      flash[:warning] = "Incorrect password"
    end
    redirect_to hunt_results_path(hunt_code: @hunt.code.upcase)
  end

  def presenter
    @hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
    @presentation = @hunt.presentation
    if @presentation.empty?
      flash[:warning] = "No submissions yet!"
      return redirect_to hunt_path(code: @hunt.code.upcase)
    end

    @big_screen = params[:screen] == "big"
    @browsing = !@big_screen && @presentation.include?(params[:slide])
    @slide = @browsing ? @presentation.slide(params[:slide]) : @presentation.current
    @screen_chat = @big_screen && @hunt.screen_chat_visible?
    @presenter_mode = true
  end

  def print
    @hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
  end

  private

  def hunt_params
    params.require(:hunt).permit(:template, :timezone, :name, :starts_at, :ends_at, :lock_results, :lock_password,
      :max_downvotes_to_lose_points, :chat_enabled).with_defaults(owner_id: cookies[:user_id])
  end
end
