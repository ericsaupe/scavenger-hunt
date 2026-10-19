# frozen_string_literal: true

class SubmissionsReopenedJob < ApplicationJob
  include Rails.application.routes.url_helpers

  queue_as :default
  discard_on ActiveJob::DeserializationError

  def perform(hunt, organizer_id)
    return unless hunt.reopened?

    minutes = ((hunt.ends_at - Time.current) / 1.minute).ceil
    PushNotification.new(hunt, :announcements,
      title: "Submissions are open again",
      body: "You have #{minutes} #{"minute".pluralize(minutes)} to add photos that didn't make it in to #{hunt.name}.",
      url: my_hunt_path(hunt: hunt.code),
      except: organizer_id).deliver
  end
end
