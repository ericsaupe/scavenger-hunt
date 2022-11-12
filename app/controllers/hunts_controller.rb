# frozen_string_literal: true

class HuntsController < ApplicationController
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

  def results
    @hunt = Hunt.includes(items: { submissions: :photo_attachment }).find_by!(code: params[:hunt_code].upcase)
    @results = @hunt.results
  end

  def download_results
    @hunt = Hunt.find_by!(code: params[:code].upcase)
    @hunt.create_archive_file unless @hunt.archive.attached?
    until @hunt.archive.attached?; end
    redirect_to rails_blob_path(@hunt.archive, disposition: 'attachment')
  end

  def unlock_results
    @hunt = Hunt.find_by!(code: params[:code].upcase)
    if @hunt.password == params[:password]
      @hunt.update(password_entered: true)
      flash.now[:success] = 'Results unlocked!'
    else
      flash[:warning] = 'Incorrect password'
    end
    redirect_to hunt_results_path(hunt_code: @hunt.code.upcase)
  end

  def print
    @hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
  end

  private

  def hunt_params
    params.require(:hunt).permit(:template, :timezone, :name, :starts_at, :ends_at, :lock_results, :lock_password)
  end
end
