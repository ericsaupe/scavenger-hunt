# frozen_string_literal: true

class Item < ApplicationRecord
  belongs_to :category
  has_many :submissions, dependent: :destroy
  has_many :teams, through: :submissions

  scope :with_photo_submissions, -> { joins(submissions: :photo_attachment).distinct }
end
