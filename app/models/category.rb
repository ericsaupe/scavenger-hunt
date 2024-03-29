# frozen_string_literal: true

class Category < ApplicationRecord
  belongs_to :hunt
  has_many :items, dependent: :destroy
  validates :points, numericality: {greater_than_or_equal_to: 0}
end
