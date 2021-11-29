# frozen_string_literal: true

class HuntsController < ApplicationController
  def index
    return unless params[:code]

    hunt = Hunt.find_by(code: params[:code].upcase)
    if hunt
      redirect_to hunt_path(code: params[:code].upcase)
    else
      flash[:error] = 'A scavenger hunt was not found for that code, sorry!'
    end
  end

  def show
    @hunt = Hunt.find_by!(code: params[:code].upcase)
  end

  def new
    @hunt = Hunt.new(name: params[:template])
  end

  def create
    clean_params = hunt_params
    @hunt = Templater.create_hunt!(clean_params.delete(:template))
    @hunt.update(clean_params)
    redirect_to hunt_path(code: @hunt.code.upcase)
  end

  def results
    @hunt = Hunt.includes(items: { submissions: :photo_attachment }).find_by!(code: params[:hunt_code].upcase)
  end

  def print
    @hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
  end

  private

  def hunt_params
    params.require(:hunt).permit(:template, :name, :starts_at, :ends_at)
  end
end
