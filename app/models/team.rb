# frozen_string_literal: true

class Team < ApplicationRecord
  belongs_to :hunt
  has_many :submissions, dependent: :destroy
  has_many :items, through: :submissions

  validates :name, uniqueness: {scope: :hunt, case_sensitive: false}

  after_create_commit { broadcast_append_to("teams_#{hunt_id}") }
  after_update_commit { broadcast_replace(partial: "teams/score") }

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
    winning_photo&.large_variant_url
  end
end
