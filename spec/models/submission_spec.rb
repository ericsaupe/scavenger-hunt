# frozen_string_literal: true

require "rails_helper"

RSpec.describe Submission do
  context "associations" do
    it { is_expected.to belong_to(:item).class_name("Item") }
    it { is_expected.to belong_to(:team).class_name("Team") }
  end
end
