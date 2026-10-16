# frozen_string_literal: true

class Submission < ApplicationRecord
  MAX_VIDEO_BYTES = 50.megabytes
  MAX_VIDEO_SECONDS = 30
  POSTER_SIZES = {small: [500, 500], large: [1500, 1500]}.freeze

  has_one_attached :photo do |attachable|
    attachable.variant :small, resize_to_fit: [500, 500]
    attachable.variant :large, resize_to_fit: [1500, 1500]
  end
  has_one_attached :playback

  belongs_to :item
  belongs_to :team, touch: true
  has_many :votes, dependent: :destroy

  delegate :hunt, to: :team
  delegate :max_downvotes_to_lose_points, to: :hunt

  validate :photo_within_limits, if: -> { attachment_changes["photo"] }

  after_save do
    @photo_changed = attachment_changes.key?("photo")
    @leaderboard_changed = @photo_changed || saved_change_to_denied_points?
  end
  after_update_commit { broadcast_replace_to("submissions_#{team_id}") }
  after_update_commit :announce_lead_change, if: -> { @leaderboard_changed }
  after_commit :refresh_playback, on: [:create, :update], if: -> { @photo_changed }

  scope :found, -> { joins(:photo_attachment) }
  scope :with_points, -> { where(denied_points: false) }

  def image?
    !!photo&.blob&.content_type&.include?("image")
  end

  def video?
    !!photo&.blob&.content_type&.include?("video")
  end

  def processing_video?
    video? && !playback.attached?
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
    return media_url if video?

    routes.rails_representation_path(photo.variant(size), only_path: true)
  end

  def media_url
    return nil unless photo.attached?

    routes.rails_blob_path(playback.attached? ? playback : photo, only_path: true)
  end

  def poster(size)
    photo.preview(resize_to_limit: POSTER_SIZES.fetch(size))
  end

  def poster_url(size = :large)
    return nil unless video? && playback.attached? && photo.previewable?

    routes.rails_representation_path(poster(size), only_path: true)
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

  def routes
    Rails.application.routes.url_helpers
  end

  def announce_lead_change
    @leaderboard_changed = false
    LeadChangeJob.perform_later(hunt)
  end

  def refresh_playback
    @photo_changed = false
    playback.purge_later if playback.attached?
    TranscodeVideoJob.perform_later(self) if video?
  end

  def photo_within_limits
    if video?
      if photo.byte_size > MAX_VIDEO_BYTES
        errors.add(:photo, "Videos must be 50 MB or smaller")
      elsif video_duration.to_f > MAX_VIDEO_SECONDS
        errors.add(:photo, "Videos must be #{MAX_VIDEO_SECONDS} seconds or shorter")
      end
    elsif !image?
      errors.add(:photo, "Only photos and videos can be uploaded")
    end
  end

  def video_duration
    blob = photo.blob
    blob.analyze if blob.persisted?
    blob.metadata[:duration]
  rescue ActiveStorage::IntegrityError
    errors.add(:photo, "The video didn't upload completely. Please try again")
    nil
  end
end
