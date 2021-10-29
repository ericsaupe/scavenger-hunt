# frozen_string_literal: true

class Submission < ApplicationRecord
  has_one_attached :photo

  belongs_to :item
  belongs_to :team, touch: true

  after_update_commit { broadcast_replace_to("submissions_#{team_id}") }

  scope :with_attached_photo, -> { joins(:photo_attachment).where.not(active_storage_attachments: { id: nil }) }

  def image?
    photo&.blob&.content_type&.include?('image')
  end

  def video?
    photo&.blob&.content_type&.include?('video')
  end
end
