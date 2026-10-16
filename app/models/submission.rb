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

  def calculate_denied_points
    return unless max_downvotes_to_lose_points&.positive?

    denied_vote_ratio = votes.denied.count / max_downvotes_to_lose_points.to_f
    if denied_vote_ratio >= 1 && !denied_points?
      update(denied_points: true)
    elsif denied_vote_ratio < 1 && denied_points?
      update(denied_points: false)
    end
    broadcast_replace_to("submission_#{id}_downvote_counter",
      target: "submission_#{id}_downvote_counter",
      partial: "items/downvote_counter",
      locals: {submission: self, disable_turbo_stream: true})
  end
end
