class DetachUntransformableSubmissionPhotos < ActiveRecord::Migration[8.1]
  def up
    attachments = ActiveStorage::Attachment.joins(:blob).where(record_type: "Submission", name: "photo")
      .where.not("active_storage_blobs.content_type LIKE 'video/%'")
      .where.not(active_storage_blobs: {content_type: ActiveStorage.variable_content_types})
    attachments.find_each(&:destroy)
  end

  def down
  end
end
