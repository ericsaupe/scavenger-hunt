# frozen_string_literal: true

FactoryBot.define do
  factory :hunt do
    name { Faker::Movies::HarryPotter.quote }
  end
end
