# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include ActiveStorage::SetCurrent
  include ChatIdentity

  before_action :set_user_id

  helper_method :current_push_subscription

  private

  def current_push_subscription
    return unless @hunt&.persisted?

    @current_push_subscription ||= @hunt.push_subscriptions.find_by(user_id: cookies[:user_id])
  end

  def set_user_id
    cookies.permanent[:user_id] = cookies[:user_id].presence || SecureRandom.uuid
  end
end
