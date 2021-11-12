# frozen_string_literal: true

FactoryBot.define do
  factory :item do
    category
    name { Faker::Movies::HarryPotter.location }
  end
end
