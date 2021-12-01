# frozen_string_literal: true

class HomeController < ApplicationController
  def index
    return unless params[:code]

    hunt = Hunt.find_by(code: params[:code].upcase)
    if hunt
      redirect_to hunt_path(code: params[:code].upcase)
    else
      flash[:error] = 'A scavenger hunt was not found for that code, sorry!'
    end
  end
end
