# frozen_string_literal: true

class PushNotification
  EVENTS = %i[starting_soon results show lead_change announcements].freeze

  attr_reader :hunt, :event, :title, :body, :url, :except

  def initialize(hunt, event, title:, body:, url:, except: nil)
    raise ArgumentError, "unknown event #{event.inspect}" unless EVENTS.include?(event)

    @hunt = hunt
    @event = event
    @title = title
    @body = body
    @url = url
    @except = except
  end

  def deliver
    return 0 unless PushSubscription.configured?

    subscriptions.find_each.count do |subscription|
      subscription.deliver(title:, body:, url:, tag: "#{event}-#{hunt.id}")
    end
  end

  private

  def subscriptions
    scope = hunt.push_subscriptions.for_event(event)
    except ? scope.where.not(user_id: except) : scope
  end
end
