# frozen_string_literal: true

FactoryBot.define do
  factory :category do
    hunt
    name { Faker::Movies::HarryPotter.character }
    points { Faker::Number.between(from: 1, to: 10) }
  end
end
