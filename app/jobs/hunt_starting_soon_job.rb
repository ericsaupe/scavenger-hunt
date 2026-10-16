# frozen_string_literal: true

class HuntStartingSoonJob < ApplicationJob
  include Rails.application.routes.url_helpers

  queue_as :default
  discard_on ActiveJob::DeserializationError

  def perform(hunt, starts_at)
    return unless hunt.starts_at&.to_i == starts_at.to_i
    return unless hunt.upcoming?

    PushNotification.new(hunt, :starting_soon,
      title: "#{hunt.name} starts in 5 minutes",
      body: "Round up your team and open your list.",
      url: hunt_path(hunt.code)).deliver
  end
end
