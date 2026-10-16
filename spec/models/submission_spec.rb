# frozen_string_literal: true

require "rails_helper"

RSpec.describe Submission do
  context "associations" do
    it { is_expected.to belong_to(:item).class_name("Item") }
    it { is_expected.to belong_to(:team).class_name("Team") }
  end

  describe "#photo_extension" do
    let(:submission) { create(:submission) }

    before { allow(ActiveStorage::Current).to receive(:url_options).and_return(host: "localhost:3000") }

    def attach(filename, content_type, fixture: "test.jpg")
      submission.photo.attach(io: Rails.root.join("spec/fixtures", fixture).open, filename:, content_type:, identify: false)
    end

    it "uses .mp4 for mp4 videos" do
      attach("video.mp4", "video/mp4", fixture: "video.mp4")
      expect(submission.photo_extension).to eq(".mp4")
    end

    it "keeps the uploaded extension when it matches the content type" do
      attach("IMG_0001.MOV", "video/quicktime", fixture: "video.mp4")
      expect(submission.photo_extension).to eq(".mov")
    end

    it "falls back to the content type when the filename has no extension" do
      attach("undefined", "image/jpeg")
      expect(submission.photo_extension).to eq(".jpg")
    end

    it "falls back to the content type when the extension does not match it" do
      attach("photo.png", "image/jpeg")
      expect(submission.photo_extension).to eq(".jpg")
    end
  end
end
