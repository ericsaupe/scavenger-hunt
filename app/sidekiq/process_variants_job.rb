# frozen_string_literal: true

class ProcessVariantsJob
  include Sidekiq::Job

  def perform(submission_id)
    Submission.find(submission_id).process_variants
  end
end
