# frozen_string_literal: true

FactoryBot.define do
  sequence :hunt_name do |n|
    "#{Faker::Movies::HarryPotter.quote} #{n}"
  end

  factory :hunt do
    name { generate(:hunt_name) }
    max_downvotes_to_lose_points { 1 }

    after :create do |hunt|
      category = create(:category, hunt:)
      create_list(:item, 3, category:)
    end
  end
end
