# frozen_string_literal: true

class Submission < ApplicationRecord
  has_one_attached :photo do |attachable|
    attachable.variant :small, resize_to_fit: [500, 500]
    attachable.variant :large, resize_to_fit: [1500, 1500]
  end

  belongs_to :item
  belongs_to :team, touch: true
  has_many :votes, dependent: :destroy

  delegate :hunt, to: :team
  delegate :max_downvotes_to_lose_points, to: :hunt

  after_update_commit { broadcast_replace_to("submissions_#{team_id}") }

  scope :with_attached_photo, -> { joins(:photo_attachment).where.not(active_storage_attachments: {id: nil}) }
  scope :with_points, -> { where(denied_points: false) }

  def image?
    !!photo&.blob&.content_type&.include?("image")
  end

  def video?
    !!photo&.blob&.content_type&.include?("video")
  end

  def large_variant_url
    return nil unless photo.attached?

    video? ? Rails.application.routes.url_helpers.url_for(photo) : photo.variant(:large).processed.url
  end

  def calculate_denied_points
    return unless max_downvotes_to_lose_points.positive?

    denied_vote_ratio = votes.denied.count / max_downvotes_to_lose_points.to_f
    should_broadcast_changes = false
    if denied_vote_ratio >= 1 && !denied_points?
      update(denied_points: true)
      should_broadcast_changes = true
    elsif denied_vote_ratio < 1 && denied_points?
      update(denied_points: false)
      should_broadcast_changes = true
    end
    broadcast_replace_to("submission_#{id}_downvote_counter",
                        target: "submission_#{id}_downvote_counter",
                        partial: "items/downvote_counter",
                        locals: { submission: self }) if should_broadcast_changes
  end
end
