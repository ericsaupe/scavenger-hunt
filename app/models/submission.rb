# frozen_string_literal: true

class Submission < ApplicationRecord
  has_one_attached :photo

  belongs_to :item
  belongs_to :team

  after_update_commit { broadcast_replace_to("submissions_#{team_id}") }
end
