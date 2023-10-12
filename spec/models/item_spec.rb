# frozen_string_literal: true

require "rails_helper"

RSpec.describe Item do
  context "associations" do
    it { is_expected.to belong_to(:category).class_name("Category") }
    it { is_expected.to have_many(:submissions).class_name("Submission") }
    it { is_expected.to have_many(:teams).class_name("Team") }
  end
end
