# frozen_string_literal: true

FactoryBot.define do
  sequence :item_name do |n|
    "#{Faker::Movies::HarryPotter.location}-#{n}"
  end

  factory :item do
    category
    name { generate(:item_name) }
  end
end
