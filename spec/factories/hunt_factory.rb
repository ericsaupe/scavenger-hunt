# frozen_string_literal: true

FactoryBot.define do
  factory :hunt do
    name { Faker::Movies::HarryPotter.quote }
    max_downvotes_to_lose_points { 1 }

    after :create do |hunt|
      category = create(:category, hunt:)
      create_list(:item, 3, category:)
    end
  end
end
