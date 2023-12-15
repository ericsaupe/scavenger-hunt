# frozen_string_literal: true

class Team < ApplicationRecord
  belongs_to :hunt
  has_many :submissions, dependent: :destroy
  has_many :items, through: :submissions

  validates :name, uniqueness: {scope: :hunt, case_sensitive: false}

  after_create_commit { broadcast_append_to("teams_#{hunt_id}") }
  after_update_commit { broadcast_replace(partial: "teams/score") }

  def score
    submissions.with_points.includes(item: :category).with_attached_photo.sum { |submission| submission.item.category.points }
  end

  def total_score
    submissions.includes(item: :category).with_attached_photo.sum { |submission| submission.item.category.points }
  end

  def victory_photo_url(winning_item_name: nil)
    if winning_item_name.present?
      winning_item = hunt.items.find_by(name: winning_item_name)
      winning_photo ||= submissions.with_attached_photo.find_by(item: winning_item)
    end

    if Vote.loved.where(submission: submissions).count.positive?
      winning_photo ||= submissions
        .select("submissions.*, COUNT(votes.id) AS votes_count")
        .joins(:votes)
        .where(votes: {value: "love"})
        .order("votes_count DESC").group("submissions.id")
        .first
    end

    winning_photo ||= submissions.with_attached_photo.sample
    winning_photo.large_variant_url
  end
end
