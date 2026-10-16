# frozen_string_literal: true

class ShowStartingJob < ApplicationJob
  include Rails.application.routes.url_helpers

  queue_as :default
  discard_on ActiveJob::DeserializationError

  def perform(hunt)
    PushNotification.new(hunt, :show,
      title: "The show is starting",
      body: "The photos from #{hunt.name} are going up on the big screen. Watch along from your phone.",
      url: hunt_presenter_path(hunt.code)).deliver
  end
end
