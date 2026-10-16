# frozen_string_literal: true

class Presentation
  DIRECTIONS = %w[next previous].freeze

  attr_reader :hunt

  def initialize(hunt)
    @hunt = hunt
  end

  def submission_ids
    @submission_ids ||= hunt.submissions.found.order(:item_id, :team_id).ids
  end

  def empty?
    submission_ids.empty?
  end

  def count
    submission_ids.size
  end

  def current_id
    return nil if empty?

    submission_ids.include?(hunt.presentation_submission_id) ? hunt.presentation_submission_id : submission_ids.first
  end

  def current
    @current ||= submissions.find(current_id) unless empty?
  end

  def position
    submission_ids.index(current_id) + 1 unless empty?
  end

  def next_id
    submission_ids[position % count] unless empty?
  end

  def previous_id
    submission_ids[position - 2] unless empty?
  end

  def step_id(direction)
    case direction
    when "next" then next_id
    when "previous" then previous_id
    end
  end

  def submissions
    hunt.submissions.found.includes(:item, :team, photo_attachment: :blob)
  end
end
