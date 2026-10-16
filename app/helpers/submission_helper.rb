# frozen_string_literal: true

module SubmissionHelper
  def submission_attachment_url(submission, variant_size: :small)
    submission.variant_url(variant_size)
  end
end
