require "rails_helper"

RSpec.describe ApplicationHelper do
  include ActiveSupport::Testing::TimeHelpers

  describe "#daisy_theme" do
    it "returns the cmyk theme" do
      travel_to Time.zone.local(2023, 4, 12, 1, 0, 0) do
        expect(helper.daisy_theme).to eq("cmyk")
      end
    end

    it "returns the halloween theme in October" do
      travel_to Time.zone.local(2023, 10, 1, 1, 0, 0) do
        expect(helper.daisy_theme).to eq("halloween")
      end
    end

    it "returns the winter theme in November" do
      travel_to Time.zone.local(2023, 11, 1, 1, 0, 0) do
        expect(helper.daisy_theme).to eq("winter")
      end
    end

    it "returns the winter theme in December" do
      travel_to Time.zone.local(2023, 12, 1, 1, 0, 0) do
        expect(helper.daisy_theme).to eq("winter")
      end
    end
  end
end
