# frozen_string_literal: true

FactoryBot.define do
  factory :team do
    hunt
    name { Faker::Team.name }

    after :create do |team|
      team.hunt.start_a_new_team(team.name)
    end
  end
end
