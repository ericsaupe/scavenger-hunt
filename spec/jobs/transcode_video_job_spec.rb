# frozen_string_literal: true

require "rails_helper"

RSpec.describe TranscodeVideoJob, :test_queue_adapter do
  include Rails.application.routes.url_helpers

  let(:submission) { create(:video_submission) }
  let(:log) { Tempfile.new("ffmpeg", Rails.root.join("tmp")) }

  around do |example|
    ENV["FAKE_FFMPEG_LOG"] = log.path
    example.run
  ensure
    ENV.delete("FAKE_FFMPEG_LOG")
    ENV.delete("FAKE_FFMPEG_FAIL")
    log.close!
  end

  def ffmpeg_calls
    log.rewind
    log.readlines.map { |line| line.chomp.split("\t") }
  end

  it "converts the original to a playable MP4 and attaches it alongside the original" do
    described_class.perform_now(submission)

    conversion = ffmpeg_calls.find { |args| args.last.end_with?("/playback.mp4") }
    original = conversion[conversion.index("-i") + 1]
    expect(original).to end_with(".mp4")
    expect(conversion).to eq(VideoTranscoder.new(original, conversion.last).command.drop(VideoTranscoder::NICE.size + 1))
    expect(conversion).to include("-t", "30", "-c:v", "libx264", "-movflags", "+faststart")
    expect(submission.reload.playback).to be_attached
    expect(submission.playback.blob).to have_attributes(filename: have_attributes(to_s: "playback.mp4"), content_type: "video/mp4", byte_size: Rails.root.join("spec/fixtures/video.mp4").size)
    expect(submission.photo.blob.filename.to_s).to eq("video.mp4")
    expect(submission.media_url).to eq(rails_blob_path(submission.playback))
  end

  it "draws the poster at both sizes so no request has to" do
    described_class.perform_now(submission)

    preview_image = submission.photo.blob.preview_image
    expect(preview_image).to be_attached
    expect(ActiveStorage::VariantRecord.where(blob: preview_image.blob).count).to eq(2)
    expect(ffmpeg_calls.count { |args| args.include?("image2") }).to eq(1)
    expect(submission.poster_url(:small)).to start_with("/rails/active_storage/representations/redirect/")
  end

  it "re-renders the team's checklist row once the playable version is ready" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)

    described_class.perform_now(submission)

    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with("submissions_#{submission.team_id}", hash_including(target: submission)).at_least(:once)
  end

  it "reports a failed conversion and leaves the original in use" do
    ENV["FAKE_FFMPEG_FAIL"] = "1"
    allow(Rails.error).to receive(:report)

    described_class.perform_now(submission)

    expect(Rails.error).to have_received(:report).with(an_instance_of(VideoTranscoder::Error), handled: true, context: {submission_id: submission.id})
    expect(submission.reload.playback).not_to be_attached
    expect(submission.media_url).to eq(rails_blob_path(submission.photo))
    expect(submission.poster_url).to be_nil
  end

  it "restricts the poster frame to plain video files too" do
    described_class.perform_now(submission)

    poster = ffmpeg_calls.find { |args| args.include?("image2") }
    expect(poster.first(4)).to eq(VideoTranscoder::INPUT_OPTIONS)
    expect(ffmpeg_calls.find { |args| args.last.end_with?("/playback.mp4") }).not_to include("nice")
  end

  it "probes every upload and takes back a video longer than thirty seconds", ffprobe_duration: 31 do
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
    submission.photo.blob.update!(metadata: {analyzed: true, duration: 1})
    blob = submission.photo.blob

    expect { described_class.perform_now(submission) }.to have_enqueued_job(LeadChangeJob).with(submission.hunt)

    expect(submission.reload.photo).not_to be_attached
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
    expect(ffmpeg_calls).to be_empty
    expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with("submissions_#{submission.team_id}",
      target: "flash", partial: "banners/banner", locals: {message: "Videos must be 30 seconds or shorter. Try a shorter clip."})
  end

  it "takes back a video whose upload did not match its checksum" do
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
    blob = ActiveStorage::Blob.create_before_direct_upload!(filename: "clip.mp4", content_type: "video/mp4", byte_size: 1.megabyte, checksum: "abc")
    blob.service.upload(blob.key, Rails.root.join("spec/fixtures/video.mp4").open)
    submission.photo.attach(blob)

    described_class.perform_now(submission)

    expect(submission.reload.photo).not_to be_attached
    expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with("submissions_#{submission.team_id}",
      hash_including(locals: {message: "The video didn't upload completely. Please try again."}))
  end

  it "drops a conversion whose clip was retaken while it ran" do
    retake = Rails.root.join("spec/fixtures/test.jpg")
    allow(VideoTranscoder).to receive(:transcode).and_wrap_original do |original, *args|
      Submission.find(submission.id).photo.attach(io: retake.open, filename: "retake.jpg")
      original.call(*args)
    end

    described_class.perform_now(submission)

    expect(submission.reload.playback).not_to be_attached
    expect(submission.photo.blob.filename.to_s).to eq("retake.jpg")
  end

  it "leaves photos and already converted videos alone" do
    photo = create(:photo_submission)
    submission.playback.attach(io: Rails.root.join("spec/fixtures/video.mp4").open, filename: "playback.mp4", content_type: "video/mp4")

    described_class.perform_now(photo)
    described_class.perform_now(submission)

    expect(ffmpeg_calls).to be_empty
    expect(photo.reload.playback).not_to be_attached
  end

  it "runs one conversion at a time on the worker" do
    expect(described_class.good_job_concurrency_rules).to contain_exactly(have_attributes(label: "transcode_video", apply_label: true, perform_limit: 1))
  end
end
