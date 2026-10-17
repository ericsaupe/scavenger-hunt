# frozen_string_literal: true

FactoryBot.define do
  factory :message do
    hunt
    user_id { SecureRandom.uuid }
    sender_name { Faker::Name.first_name }
    content { Faker::Lorem.sentence }
  end
end
