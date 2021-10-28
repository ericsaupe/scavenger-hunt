# frozen_string_literal: true

class Submission < ApplicationRecord
  has_one_attached :photo

  belongs_to :item
  belongs_to :team
end
