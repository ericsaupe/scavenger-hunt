# frozen_string_literal: true

class PushSubscriptionsController < ApplicationController
  before_action :set_hunt

  def create
    subscription = @hunt.push_subscriptions.find_or_initialize_by(user_id: cookies[:user_id])
    subscription.assign_attributes(subscription_params.merge(user_agent: request.user_agent.to_s.first(255)))

    if subscription.save
      head :no_content
    else
      render json: {errors: subscription.errors.full_messages}, status: :unprocessable_content
    end
  end

  def update
    subscription = @hunt.push_subscriptions.find_by!(user_id: cookies[:user_id])
    subscription.update!(preference_params)
    head :no_content
  end

  def destroy
    @hunt.push_subscriptions.where(user_id: cookies[:user_id]).destroy_all
    head :no_content
  end

  private

  def set_hunt
    @hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
  end

  def subscription_params
    subscription = params.require(:subscription)
    {
      endpoint: subscription[:endpoint],
      p256dh: subscription.dig(:keys, :p256dh),
      auth: subscription.dig(:keys, :auth)
    }
  end

  def preference_params
    params.require(:push_subscription).permit(*PushSubscription::PREFERENCES)
  end
end
