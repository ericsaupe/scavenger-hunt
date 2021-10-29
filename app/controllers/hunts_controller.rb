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

  def results
    @hunt = Hunt.includes(items: { submissions: :photo_attachment }).find_by!(code: params[:hunt_code].upcase)
  end
end
