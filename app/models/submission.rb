# frozen_string_literal: true

class Submission < ApplicationRecord
  has_one_attached :photo do |attachable|
    attachable.variant :small, resize_to_fit: [500, 500]
    attachable.variant :large, resize_to_fit: [1500, 1500]
  end

  belongs_to :item
  belongs_to :team, touch: true

  delegate :hunt, to: :team

  after_update_commit { broadcast_replace_to("submissions_#{team_id}") }

  scope :with_attached_photo, -> { joins(:photo_attachment).where.not(active_storage_attachments: { id: nil }) }

  def image?
    photo&.blob&.content_type&.include?('image')
  end

  def video?
    photo&.blob&.content_type&.include?('video')
  end
end
