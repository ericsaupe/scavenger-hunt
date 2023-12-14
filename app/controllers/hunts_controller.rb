# frozen_string_literal: true

class HuntsController < ApplicationController
  caches_action :index, expires_in: 1.day

  def index
    @templates = Templater.templates.sort_by { |hunt| hunt[:name] }
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
    @hunt.create_archive_file unless @hunt.archive.attached?
    until @hunt.archive.attached?; end
    redirect_to rails_blob_path(@hunt.archive, disposition: "attachment")
  end

  def unlock_results
    @hunt = Hunt.find_by!(code: params[:code].upcase)
    if @hunt.password == params[:password]
      @hunt.update(password_entered: true, owner_id: cookies[:user_id])
      flash.now[:success] = "Results unlocked!"
    else
      flash[:warning] = "Incorrect password"
    end
    redirect_to hunt_results_path(hunt_code: @hunt.code.upcase)
  end

  def presenter
    @hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
    submissions = @hunt.submissions.includes(:item, :team).with_attached_photo.order(:item_id, :team_id)
    if submissions.empty?
      flash[:warning] = "No submissions yet!"
      return redirect_to hunt_path(code: @hunt.code.upcase)
    end

    if ActiveModel::Type::Boolean.new.cast(params[:become_presenter]) && !@hunt.owner?(cookies[:user_id])
      @hunt.update(owner_id: cookies[:user_id])
    end

    @submission = if params[:submission_id].present?
      submissions.find(params[:submission_id])
    else
      submissions.first
    end
    @next_submission = submissions.where.not(id: @submission.id).where("team_id > ?", @submission.team_id)
      .order("item_id ASC").first || submissions.where.not(id: @submission.id).first
    @previous_submission = submissions.where.not(id: @submission.id).where("team_id < ?", @submission.team_id)
      .order("item_id DESC").first || submissions.where.not(id: @submission.id).last
    @hunt.broadcast_presentation_update(@submission)
  end

  def print
    @hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
  end

  private

  def hunt_params
    params.require(:hunt).permit(:template, :timezone, :name, :starts_at, :ends_at, :lock_results, :lock_password,
      :max_downvotes_to_lose_points).with_defaults(owner_id: cookies[:user_id])
  end
end
