# frozen_string_literal: true

class Submission < ApplicationRecord
  MAX_VIDEO_BYTES = 150.megabytes
  MAX_VIDEO_SECONDS = 60
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
  after_commit :refresh_playback, on: [:create, :update], if: -> { @photo_changed }
  after_update_commit { broadcast_replace_to("submissions_#{team_id}") }
  after_update_commit :announce_lead_change, if: -> { @leaderboard_changed }

  scope :found, -> { joins(:photo_attachment) }
  scope :with_points, -> { where(denied_points: false) }

  def self.video_transcoding?
    Flipper.enabled?(:video_transcoding)
  end

  def image?
    !!photo&.blob&.content_type&.include?("image")
  end

  def video?
    !!photo&.blob&.content_type&.include?("video")
  end

  def processing_video?
    self.class.video_transcoding? && video? && !playback.attached? && !photo.blob.metadata[:playback_failed]
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
    return media_url if video? || !photo.variable?

    routes.rails_representation_path(photo.variant(size), only_path: true)
  end

  def media_aspect_ratio
    metadata = photo.attached? ? photo.blob.metadata : {}
    width, height = metadata.values_at("width", "height")
    return "#{width.to_f} / #{height.to_f}" if width.to_f.positive? && height.to_f.positive?

    video? ? "16 / 9" : "4 / 3"
  end

  def media_url
    return nil unless photo.attached?

    routes.rails_blob_path(playback_ready? ? playback : photo, only_path: true)
  end

  def poster(size)
    photo.preview(resize_to_limit: POSTER_SIZES.fetch(size))
  end

  def poster_url(size = :large)
    return nil unless video? && playback_ready? && photo.previewable?

    routes.rails_representation_path(poster(size), only_path: true)
  end

  def vote_for(user_id)
    votes.find { |vote| vote.user_id == user_id } || votes.build(user_id:)
  end

  def shown_flag_count
    [votes.count(&:denied?), max_downvotes_to_lose_points].min
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

  def playback_ready?
    self.class.video_transcoding? && playback.attached?
  end

  def announce_lead_change
    @leaderboard_changed = false
    LeadChangeJob.perform_later(hunt)
  end

  def refresh_playback
    @photo_changed = false
    if playback.attached?
      stale = playback.blob
      playback.detach
      stale.purge_later
    end
    TranscodeVideoJob.perform_later(self) if video? && self.class.video_transcoding?
  end

  def photo_within_limits
    if video?
      errors.add(:photo, "Videos must be #{MAX_VIDEO_BYTES / 1.megabyte} MB or smaller") if photo.byte_size > MAX_VIDEO_BYTES
    elsif !image?
      errors.add(:photo, "Only photos and videos can be uploaded")
    elsif !photo.variable?
      errors.add(:photo, "That image type can't be used. Take a photo instead")
    end
  end
end
