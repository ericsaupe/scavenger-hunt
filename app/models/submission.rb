# frozen_string_literal: true

class Submission < ApplicationRecord
  belongs_to :item
  belongs_to :team
end
