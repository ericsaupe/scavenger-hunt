# frozen_string_literal: true

class ProcessVariantsJob < ApplicationJob
  def perform(submission_id)
    Submission.find(submission_id).process_variants
  end
end
