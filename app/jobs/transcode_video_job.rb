# frozen_string_literal: true

class TranscodeVideoJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  queue_as :default
  discard_on ActiveJob::DeserializationError
  good_job_concurrency_rule(label: "transcode_video", apply_label: true, perform_limit: 1)
  retry_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError, attempts: Float::INFINITY, wait: 5.seconds

  def perform(submission)
    return unless submission.video? && !submission.playback.attached?

    Submission::POSTER_SIZES.each_key { |size| submission.poster(size).processed }
    submission.photo.blob.open do |original|
      Dir.mktmpdir("transcode") do |dir|
        playback = VideoTranscoder.transcode(original.path, File.join(dir, "playback.mp4"))
        File.open(playback, "rb") do |io|
          submission.playback.attach(io:, filename: "playback.mp4", content_type: "video/mp4", identify: false)
        end
      end
    end
  rescue => error
    Rails.error.report(error, handled: true, context: {submission_id: submission.id})
  end
end
