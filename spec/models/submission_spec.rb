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

  describe "#variant_url" do
    before { allow(ActiveStorage::Current).to receive(:url_options).and_return(host: "localhost:3000") }

    it "links images to a permanent URL that processes the variant when first requested" do
      submission = create(:photo_submission)

      expect(submission.small_variant_url).to start_with("/rails/active_storage/representations/redirect/")
      expect(submission.large_variant_url).to start_with("/rails/active_storage/representations/redirect/")
      expect(ActiveStorage::VariantRecord.count).to eq(0)
    end

    it "links videos to the playable version" do
      submission = create(:video_submission)

      expect(submission.large_variant_url).to eq(submission.media_url)
      expect(submission.large_variant_url).to start_with("/rails/active_storage/blobs/redirect/")
    end

    it "is nil without a photo" do
      expect(create(:submission).small_variant_url).to be_nil
    end
  end

  describe "#media_url" do
    include Rails.application.routes.url_helpers

    it "serves the original video until the playable version exists", :test_queue_adapter do
      submission = create(:video_submission)

      expect(submission.media_url).to eq(rails_blob_path(submission.photo))
      expect(submission.poster_url).to be_nil
      expect(submission).to be_processing_video
    end

    it "serves the playable version with its poster once the job has made them" do
      submission = create(:video_submission).reload

      expect(submission.playback).to be_attached
      expect(submission.media_url).to eq(rails_blob_path(submission.playback))
      expect(submission.media_url).not_to eq(rails_blob_path(submission.photo))
      expect(submission.poster_url).to start_with("/rails/active_storage/representations/redirect/")
      expect(submission.poster_url(:small)).not_to eq(submission.poster_url(:large))
      expect(submission).not_to be_processing_video
    end

    it "serves photos as variants" do
      submission = create(:photo_submission)

      expect(submission.media_url).to eq(rails_blob_path(submission.photo))
      expect(submission.large_variant_url).to start_with("/rails/active_storage/representations/redirect/")
      expect(submission.playback).not_to be_attached
    end

    it "drops the playable version and makes a new one when the video is retaken", :test_queue_adapter do
      submission = create(:video_submission)
      submission.playback.attach(io: Rails.root.join("spec/fixtures/video.mp4").open, filename: "playback.mp4", content_type: "video/mp4")
      old_playback = submission.playback.blob

      expect {
        submission.photo.attach(io: Rails.root.join("spec/fixtures/video.mp4").open, filename: "retake.mp4")
      }.to have_enqueued_job(TranscodeVideoJob).with(submission).and have_enqueued_job(ActiveStorage::PurgeJob).with(old_playback)
      expect(submission.reload.playback).not_to be_attached
      expect(submission.media_url).to eq(rails_blob_path(submission.photo))
    end

    it "drops the playable version when a photo replaces the video", :test_queue_adapter do
      submission = create(:video_submission)
      submission.playback.attach(io: Rails.root.join("spec/fixtures/video.mp4").open, filename: "playback.mp4", content_type: "video/mp4")

      expect {
        submission.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
      }.not_to have_enqueued_job(TranscodeVideoJob)
      expect(submission.reload.playback).not_to be_attached
      expect(submission.media_url).to start_with("/rails/active_storage/blobs/redirect/")
    end
  end

  describe "retaking a converted video", :test_queue_adapter do
    include Rails.application.routes.url_helpers

    it "broadcasts the row without the old playback and with the processing state" do
      submission = create(:video_submission)
      submission.playback.attach(io: Rails.root.join("spec/fixtures/video.mp4").open, filename: "playback.mp4", content_type: "video/mp4")
      old_playback = rails_blob_path(submission.playback)
      broadcast_urls = []
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to) do |_stream, **options|
        broadcast_urls << options[:locals][:submission].media_url if options.dig(:locals, :submission)
      end

      submission.photo.attach(io: Rails.root.join("spec/fixtures/video.mp4").open, filename: "retake.mp4")

      expect(broadcast_urls).not_to be_empty
      expect(broadcast_urls).to all(eq(rails_blob_path(submission.photo)))
      expect(broadcast_urls).not_to include(old_playback)
    end
  end
end
