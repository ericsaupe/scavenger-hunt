# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ActiveStorage::SetCurrent

  before_action :set_user_id

  private

  def set_user_id
    cookies.permanent[:user_id] = cookies[:user_id].presence || SecureRandom.uuid
  end
end
