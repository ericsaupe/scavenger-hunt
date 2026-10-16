# frozen_string_literal: true

class PushNotification
  EVENTS = %i[starting_soon results show lead_change].freeze

  attr_reader :hunt, :event, :title, :body, :url

  def initialize(hunt, event, title:, body:, url:)
    raise ArgumentError, "unknown event #{event.inspect}" unless EVENTS.include?(event)

    @hunt = hunt
    @event = event
    @title = title
    @body = body
    @url = url
  end

  def deliver
    return 0 unless PushSubscription.configured?

    hunt.push_subscriptions.for_event(event).find_each.count do |subscription|
      subscription.deliver(title:, body:, url:, tag: "#{event}-#{hunt.id}")
    end
  end
end
