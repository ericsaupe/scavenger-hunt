# frozen_string_literal: true

module SubmissionHelper
  def submission_attachment_url(submission)
    return nil unless submission.photo.attached?

    if submission.video?
      url_for(submission.photo)
    else
      url_for(submission.photo.variant(resize_to_fit: [500, 500]))
    end
  end
end
