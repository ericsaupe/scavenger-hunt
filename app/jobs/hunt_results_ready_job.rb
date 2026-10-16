# frozen_string_literal: true

class HuntResultsReadyJob < ApplicationJob
  include Rails.application.routes.url_helpers

  queue_as :default
  discard_on ActiveJob::DeserializationError

  def perform(hunt, ends_at)
    return unless hunt.ends_at&.to_i == ends_at.to_i
    return unless hunt.ended?

    PushNotification.new(hunt, :results,
      title: "#{hunt.name} is over",
      body: "Results are up. See who won and vote on the photos.",
      url: hunt_results_path(hunt.code)).deliver
  end
end
