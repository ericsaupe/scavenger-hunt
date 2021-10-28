# frozen_string_literal: true

class Item < ApplicationRecord
  belongs_to :category
  has_many :submissions, dependent: :destroy
  has_many :teams, through: :submissions
end
