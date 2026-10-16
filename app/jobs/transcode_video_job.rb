# frozen_string_literal: true

class TranscodeVideoJob < ApplicationJob
  include GoodJob::ActiveJobExtensions::Concurrency

  TOO_LONG = "Videos must be #{Submission::MAX_VIDEO_SECONDS} seconds or shorter. Try a shorter clip."
  INCOMPLETE = "The video didn't upload completely. Please try again."

  queue_as :default
  discard_on ActiveJob::DeserializationError
  good_job_concurrency_rule(label: "transcode_video", apply_label: true, perform_limit: 1)
  retry_on GoodJob::ActiveJobExtensions::Concurrency::ConcurrencyExceededError, attempts: Float::INFINITY, wait: 5.seconds

  def perform(submission)
    return unless submission.video? && !submission.playback.attached?

    source = submission.photo.blob
    source.analyze
    probed_duration = source.metadata[:duration]
    return refuse(submission, source, TOO_LONG) if probed_duration.to_f > Submission::MAX_VIDEO_SECONDS

    Submission::POSTER_SIZES.each_key { |size| submission.poster(size).processed }
    source.open do |original|
      Dir.mktmpdir("transcode") do |dir|
        playback = VideoTranscoder.transcode(original.path, File.join(dir, "playback.mp4"))
        return refuse(submission, source, TOO_LONG) if probed_duration.nil? && too_long?(playback)

        File.open(playback, "rb") do |io|
          submission.with_lock do
            submission.playback.attach(io:, filename: "playback.mp4", content_type: "video/mp4", identify: false) if submission.photo.blob == source
          end
        end
      end
    end
  rescue ActiveStorage::IntegrityError
    refuse(submission, source, INCOMPLETE)
  rescue => error
    Rails.error.report(error, handled: true, context: {submission_id: submission.id})
    give_up(submission, source)
  end

  private

  def too_long?(playback)
    VideoTranscoder.duration(playback).to_f > Submission::MAX_VIDEO_SECONDS + 0.1
  end

  def refuse(submission, source, message)
    refused = submission.with_lock do
      next false unless submission.photo.blob == source

      submission.photo.purge
      true
    end
    return unless refused

    LeadChangeJob.perform_later(submission.hunt)
    Turbo::StreamsChannel.broadcast_append_to("submissions_#{submission.team_id}",
      target: "flash", partial: "banners/banner", locals: {message:})
  end

  def give_up(submission, source)
    source.update!(metadata: source.metadata.merge(playback_failed: true))
    submission.touch if submission.photo.blob == source
  end
end
