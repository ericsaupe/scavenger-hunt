# frozen_string_literal: true

require "rails_helper"

RSpec.describe HuntTemplate do
  subject(:template) do
    described_class.new(
      name: "Christmas Light Spectacle",
      categories: [
        {name: "Lights", points: 1, items: ["Icicle Lights", "Blinking Lights"]},
        {name: "Challenges", points: 10, items: ["Hug a snowman"]}
      ]
    )
  end

  it "derives its slug from its name" do
    expect(template.slug).to eq("christmas-light-spectacle")
    expect(template.to_param).to eq("christmas-light-spectacle")
  end

  it "sums up its items, points and possible score" do
    expect(template.item_count).to eq(3)
    expect(template.points_range).to eq(1..10)
    expect(template.possible_score).to eq(12)
  end

  it "falls back to the generic image" do
    expect(template.image_path).to eq("templates/scavenger.jpg")
  end
end
