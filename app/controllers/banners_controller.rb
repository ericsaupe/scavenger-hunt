# frozen_string_literal: true

class BannersController < ApplicationController
  layout false

  def show
    @message = params[:message]
  end
end
