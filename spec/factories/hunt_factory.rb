# frozen_string_literal: true

FactoryBot.define do
  factory :hunt do
    name { Faker::Movies::HarryPotter.quote }

    after :create do |hunt|
      category = create :category, hunt: hunt
      create_list :item, 3, category: category
    end
  end
end
