# frozen_string_literal: true

FactoryBot.define do
  factory :team do
    hunt
    name { Faker::Team.name }
  end
end
