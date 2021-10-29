# frozen_string_literal: true

class Team < ApplicationRecord
  belongs_to :hunt
  has_many :submissions, dependent: :destroy
  has_many :items, through: :submissions

  validates :name, uniqueness: { scope: :hunt, case_sensitive: false }

  after_update_commit { broadcast_replace(partial: 'teams/score') }

  def score
    submissions.includes(item: :category).with_attached_photo.sum { |submission| submission.item.category.points }
  end
end
