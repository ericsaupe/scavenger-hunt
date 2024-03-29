# frozen_string_literal: true

require "rails_helper"

RSpec.describe Category do
  context "associations" do
    it { is_expected.to belong_to(:hunt).class_name("Hunt") }
    it { is_expected.to have_many(:items).class_name("Item") }
  end

  it "validates points is greater than or equal to 0" do
    category = described_class.new(
      hunt: Hunt.new(name: "Test"),
      name: "Test Category",
      points: 100
    )
    expect(category).to be_valid
    category.points = 0
    expect(category).to be_valid
    category.points = -1
    expect(category).not_to be_valid
  end
end
