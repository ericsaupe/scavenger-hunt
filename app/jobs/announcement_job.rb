# frozen_string_literal: true

class AnnouncementJob < ApplicationJob
  include Rails.application.routes.url_helpers

  queue_as :default
  discard_on ActiveJob::DeserializationError

  def perform(message)
    return if message.removed? || !message.announcement?

    PushNotification.new(message.hunt, :announcements,
      title: "From the organizer",
      body: message.content,
      url: my_hunt_path,
      except: message.user_id).deliver
  end
end
