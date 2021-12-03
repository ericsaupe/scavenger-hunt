# frozen_string_literal: true

module SubmissionHelper
  def submission_attachment_url(submission, variant_size: :small)
    return nil unless submission.photo.attached?

    if submission.video?
      url_for(submission.photo)
    else
      url_for(submission.photo.variant(variant_size))
    end
  end
end
