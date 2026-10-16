# frozen_string_literal: true

Rails.application.configure do
  config.good_job.enable_cron = true
  config.good_job.cron = {
    purge_unattached_blobs: {
      cron: "0 4 * * *",
      class: "PurgeUnattachedBlobsJob",
      description: "Purge Active Storage blobs left behind by direct uploads whose form never arrived"
    }
  }
end
