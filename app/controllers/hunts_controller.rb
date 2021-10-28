# frozen_string_literal: true

class HuntsController < ApplicationController
  def index
    return unless params[:code]

    hunt = Hunt.find_by(code: params[:code].upcase)
    if hunt
      redirect_to hunt_path(hunt)
    else
      flash[:error] = 'A scavenger hunt was not found for that code, sorry!'
    end
  end
end
