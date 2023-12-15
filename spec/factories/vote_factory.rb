# frozen_string_literal: true

FactoryBot.define do
  factory :vote do
    submission
    user_id { SecureRandom.uuid }
    value { "love" }
  end

  factory :upvote, class: Vote do
    submission
    user_id { SecureRandom.uuid }
    value { "love" }
  end

  factory :downvote, class: Vote do
    submission
    user_id { SecureRandom.uuid }
    value { "deny" }
  end
end
