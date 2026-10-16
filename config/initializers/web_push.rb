# frozen_string_literal: true

vapid = Rails.application.credentials.vapid.to_h
public_key = vapid[:public_key].presence || ENV["VAPID_PUBLIC_KEY"].presence
private_key = vapid[:private_key].presence || ENV["VAPID_PRIVATE_KEY"].presence

if Rails.env.test? && public_key.nil?
  key = WebPush.generate_key
  public_key = key.public_key
  private_key = key.private_key
end

Rails.application.config.x.vapid = {
  subject: vapid[:subject].presence || ENV.fetch("VAPID_SUBJECT", "https://scavengerhunt.party"),
  public_key:,
  private_key:
}.freeze
