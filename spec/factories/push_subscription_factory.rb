# frozen_string_literal: true

FactoryBot.define do
  factory :push_subscription do
    hunt
    user_id { SecureRandom.uuid }
    sequence(:endpoint) { |n| "https://fcm.googleapis.com/fcm/send/#{n}" }
    p256dh { "BPtQyxOsVHNeNj8XThHO0kR" }
    auth { "k3Z9x9" }
    user_agent { "Mozilla/5.0 (iPhone)" }
  end
end
