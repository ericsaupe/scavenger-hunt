# frozen_string_literal: true

class Team < ApplicationRecord
  belongs_to :hunt
  has_many :submissions, dependent: :destroy
  has_many :items, through: :submissions

  validates :name, uniqueness: { scope: :hunt, case_sensitive: false }
end
