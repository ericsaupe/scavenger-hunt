# frozen_string_literal: true

class Team < ApplicationRecord
  belongs_to :hunt
  has_many :submissions, dependent: :destroy
  has_many :items, through: :submissions

  PENDING_UPLOADS_TTL = 5.minutes
  MAX_PENDING_REPORTERS = 25
  AVATAR_SEED_FORMAT = /\A\h{16}\z/

  validates :name, uniqueness: {scope: :hunt, case_sensitive: false}

  before_validation :assign_avatar_seed, on: :create

  after_create_commit { broadcast_append_to("teams_#{hunt_id}") }
  after_update_commit { broadcast_replace(partial: "teams/score") }

  def self.pending_uploads_for(teams)
    Rails.cache.read_multi(*teams.map { |team| team.pending_uploads_cache_key }).values.sum do |reports|
      live_pending_reports(reports).values.sum { |count, _reported_at| count }
    end
  end

  def self.new_avatar_seed
    SecureRandom.hex(8)
  end

  def self.live_pending_reports(reports)
    cutoff = PENDING_UPLOADS_TTL.ago.to_i
    (reports || {}).select { |_client, (_count, reported_at)| reported_at > cutoff }
  end

  def report_pending_uploads(client, count)
    reports = self.class.live_pending_reports(Rails.cache.read(pending_uploads_cache_key))
    count = count.clamp(0, hunt.items.count)
    if count.positive?
      reports[client] = [count, Time.current.to_i]
    else
      reports.delete(client)
    end
    reports = reports.min_by(MAX_PENDING_REPORTERS) { |_client, (_count, reported_at)| -reported_at }.to_h
    Rails.cache.write(pending_uploads_cache_key, reports, expires_in: PENDING_UPLOADS_TTL)
  end

  def pending_uploads_cache_key
    "teams/#{id}/pending_uploads"
  end

  def avatar_url(still: false)
    Avatar.for(:team, avatar_seed, initial: name, still:)
  end

  def shuffle_avatar!
    update!(avatar_seed: self.class.new_avatar_seed)
  end

  def score
    submissions.with_points.found.joins(item: :category).sum("categories.points")
  end

  def total_score
    submissions.found.joins(item: :category).sum("categories.points")
  end

  def victory_photo_url(victory_item_id: nil)
    if victory_item_id.present?
      item = hunt.items.find_by(id: victory_item_id)
      winning_photo = submissions.found.find_by(item:)
    end

    if Vote.loved.where(submission: submissions).count.positive?
      winning_photo ||= submissions
        .select("submissions.*, COUNT(votes.id) AS votes_count")
        .joins(:votes)
        .where(votes: {value: "love"})
        .order("votes_count DESC").group("submissions.id")
        .first
    end

    winning_photo ||= submissions.found.sample
    winning_photo&.video? ? winning_photo.poster_url : winning_photo&.large_variant_url
  end

  private

  def assign_avatar_seed
    self.avatar_seed = self.class.new_avatar_seed unless avatar_seed.to_s.match?(AVATAR_SEED_FORMAT)
  end
end
