# frozen_string_literal: true

class PushSubscription < ApplicationRecord
  PREFERENCES = %i[notify_starting_soon notify_results notify_show notify_lead_change].freeze
  ICON = "/android-chrome-192x192.png"
  TTL = 1.hour
  TIMEOUT = 10
  PUSH_SERVICES = [
    /\Afcm\.googleapis\.com\z/,
    /\Aupdates\.push\.services\.mozilla\.com\z/,
    /\A[a-z0-9-]+\.push\.apple\.com\z/,
    /\A[a-z0-9-]+\.notify\.windows\.com\z/
  ].freeze

  belongs_to :hunt

  validates :user_id, :p256dh, :auth, presence: true
  validates :endpoint, presence: true, format: {with: %r{\Ahttps://}}
  validate :endpoint_is_a_push_service

  scope :for_event, ->(event) { where("notify_#{event}" => true) }

  def self.configured?
    vapid[:public_key].present? && vapid[:private_key].present?
  end

  def self.vapid
    Rails.application.config.x.vapid
  end

  def deliver(title:, body:, url:, tag: nil)
    WebPush.payload_send(
      message: {title:, body:, url:, tag:, icon: ICON}.compact.to_json,
      endpoint:,
      p256dh:,
      auth:,
      vapid: self.class.vapid,
      ttl: TTL.to_i,
      urgency: "high",
      open_timeout: TIMEOUT,
      read_timeout: TIMEOUT
    )
    true
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    destroy
    false
  rescue WebPush::ResponseError, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => error
    Rails.error.report(error, handled: true)
    false
  end

  private

  def endpoint_is_a_push_service
    host = URI.parse(endpoint.to_s).host.to_s.downcase.chomp(".")
    errors.add(:endpoint, "is not a known push service") unless PUSH_SERVICES.any? { |service| service.match?(host) }
  rescue URI::InvalidURIError
    errors.add(:endpoint, "is not a valid URL")
  end
end
