# frozen_string_literal: true

namespace :videos do
  desc "Queue a playable MP4 and poster for every video submission that has none yet"
  task transcode_missing: :environment do
    queued = 0
    Submission.found.where.missing(:playback_attachment).includes(photo_attachment: :blob).find_each do |submission|
      next unless submission.video?

      TranscodeVideoJob.perform_later(submission)
      queued += 1
    end
    puts "Queued #{queued} video#{"s" unless queued == 1}"
  end
end
