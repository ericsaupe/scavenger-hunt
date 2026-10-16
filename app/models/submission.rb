# frozen_string_literal: true

class Submission < ApplicationRecord
  MAX_VIDEO_BYTES = 50.megabytes
  MAX_VIDEO_SECONDS = 30

  has_one_attached :photo do |attachable|
    attachable.variant :small, resize_to_fit: [500, 500]
    attachable.variant :large, resize_to_fit: [1500, 1500]
  end

  belongs_to :item
  belongs_to :team, touch: true
  has_many :votes, dependent: :destroy

  delegate :hunt, to: :team
  delegate :max_downvotes_to_lose_points, to: :hunt

  validate :photo_within_limits, if: -> { attachment_changes["photo"] }

  after_save { @leaderboard_changed = attachment_changes.key?("photo") || saved_change_to_denied_points? }
  after_update_commit { broadcast_replace_to("submissions_#{team_id}") }
  after_update_commit :announce_lead_change, if: -> { @leaderboard_changed }

  scope :found, -> { joins(:photo_attachment) }
  scope :with_points, -> { where(denied_points: false) }

  def image?
    !!photo&.blob&.content_type&.include?("image")
  end

  def video?
    !!photo&.blob&.content_type&.include?("video")
  end

  def photo_extension
    extensions = Marcel::Magic.new(photo.content_type).extensions
    extension = photo.filename.extension_without_delimiter.downcase
    extension = extensions.first unless extensions.include?(extension)
    ".#{extension}" if extension
  end

  def large_variant_url
    variant_url(:large)
  end

  def small_variant_url
    variant_url(:small)
  end

  def variant_url(size)
    return nil unless photo.attached?

    routes = Rails.application.routes.url_helpers
    video? ? routes.rails_blob_path(photo, only_path: true) : routes.rails_representation_path(photo.variant(size), only_path: true)
  end

  def poster_url
    return nil unless video? && photo.previewable?

    Rails.application.routes.url_helpers.rails_representation_path(photo.preview(resize_to_limit: [1500, 1500]), only_path: true)
  end

  def vote_for(user_id)
    votes.find { |vote| vote.user_id == user_id } || votes.build(user_id:)
  end

  def calculate_denied_points
    return unless max_downvotes_to_lose_points&.positive?

    denied_vote_ratio = votes.denied.count / max_downvotes_to_lose_points.to_f
    if denied_vote_ratio >= 1 && !denied_points?
      update(denied_points: true)
    elsif denied_vote_ratio < 1 && denied_points?
      update(denied_points: false)
    end
    broadcast_replace_to("submission_#{id}_flags",
      target: "submission_#{id}_flags",
      partial: "items/flag_counter",
      locals: {submission: self, disable_turbo_stream: true})
  end

  private

  def announce_lead_change
    @leaderboard_changed = false
    LeadChangeJob.perform_later(hunt)
  end

  def photo_within_limits
    if video?
      errors.add(:photo, "Videos must be 50 MB or smaller") if photo.byte_size > MAX_VIDEO_BYTES
    elsif !image?
      errors.add(:photo, "Only photos and videos can be uploaded")
    end
  end
end
