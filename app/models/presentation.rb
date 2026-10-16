# frozen_string_literal: true

class Presentation
  DIRECTIONS = %w[next previous].freeze
  FINALE = "finale"

  attr_reader :hunt

  def initialize(hunt)
    @hunt = hunt
  end

  def self.submission_key(submission_id)
    "submission:#{submission_id}"
  end

  def self.item_key(item_id)
    "item:#{item_id}"
  end

  def keys
    @keys ||= found.chunk_while { |(_, item_a), (_, item_b)| item_a == item_b }.flat_map do |group|
      [self.class.item_key(group.first.last), *group.map { |id, _| self.class.submission_key(id) }]
    end.tap { |keys| keys << FINALE unless keys.empty? || !hunt.leaderboard_visible? }
  end

  def empty?
    keys.empty?
  end

  def count
    keys.size
  end

  def include?(key)
    keys.include?(key)
  end

  def current_key
    return nil if empty?

    include?(hunt.presentation_slide) ? hunt.presentation_slide : keys.first
  end

  def position(key = current_key)
    keys.index(key) + 1 unless empty?
  end

  def next_key(key = current_key)
    keys[position(key) % count] unless empty?
  end

  def previous_key(key = current_key)
    keys[position(key) - 2] unless empty?
  end

  def step_key(direction, from: current_key)
    case direction
    when "next" then next_key(from)
    when "previous" then previous_key(from)
    end
  end

  def current
    slide(current_key)
  end

  def next_submission(key = current_key)
    next_key = keys.rotate(position(key)).find { |candidate| candidate.start_with?("submission:") }
    hunt.submissions.includes(photo_attachment: :blob).find(next_key.delete_prefix("submission:")) if next_key
  end

  def presenting?(submission)
    hunt.presentation_slide == self.class.submission_key(submission.id) && submission.photo.attached?
  end

  def broadcast_reaction(vote)
    submission = vote.submission
    return unless presenting?(submission)

    Turbo::StreamsChannel.broadcast_replace_to(hunt.presenter_stream,
      target: "submission_#{submission.id}_reactions",
      partial: "presentations/reaction_counts",
      locals: {submission:})
    return if vote.value.blank? || !ReactionThrottle.allow?(hunt, vote.user_id)

    Turbo::StreamsChannel.broadcast_append_to(hunt.presenter_stream,
      target: "reactions",
      partial: "presentations/reaction",
      locals: {value: vote.value})
  end

  def slide(key)
    return nil unless include?(key)

    kind, id = key.split(":")
    case kind
    when "submission" then PhotoSlide.new(self, key, submissions.find(id))
    when "item" then TitleCard.new(self, key, hunt.items.find(id))
    when FINALE then Finale.new(self, key)
    end
  end

  def submissions
    hunt.submissions.found.includes(:item, :team, :votes, photo_attachment: :blob)
  end

  def team_count
    @team_count ||= hunt.teams.count
  end

  private

  def found
    @found ||= hunt.submissions.found.order(:item_id, :team_id).pluck(:id, :item_id)
  end

  class Slide
    attr_reader :presentation, :key

    def initialize(presentation, key)
      @presentation = presentation
      @key = key
    end

    def position
      presentation.position(key)
    end

    def count
      presentation.count
    end

    def next_key
      presentation.next_key(key)
    end

    def previous_key
      presentation.previous_key(key)
    end

    def submission
      nil
    end

    def video?
      false
    end

    def preload_url
      upcoming = presentation.next_submission(key)
      upcoming.large_variant_url if upcoming&.image?
    end
  end

  class PhotoSlide < Slide
    attr_reader :submission

    def initialize(presentation, key, submission)
      super(presentation, key)
      @submission = submission
    end

    def partial
      "presentations/photo"
    end

    def label
      video? ? "Video" : "Photo"
    end

    def video?
      submission.video?
    end

    def title
      submission.item.name
    end

    def subtitle
      submission.team.name
    end
  end

  class TitleCard < Slide
    attr_reader :item

    def initialize(presentation, key, item)
      super(presentation, key)
      @item = item
    end

    def partial
      "presentations/title_card"
    end

    def label
      "Item"
    end

    def title
      item.name
    end

    def subtitle
      "Next up"
    end

    def submissions
      @submissions ||= presentation.submissions.where(item:).order(:team_id).to_a
    end

    def team_count
      presentation.team_count
    end

    def points
      item.category.points
    end
  end

  class Finale < Slide
    def partial
      "presentations/finale"
    end

    def label
      "Finale"
    end

    def title
      "First place"
    end

    def subtitle
      winner&.fetch(:name)
    end

    def results
      @results ||= presentation.hunt.results
    end

    def winner
      results.first
    end

    def runners_up
      results.drop(1).first(4)
    end

    def most_loved
      return @most_loved if defined?(@most_loved)

      loves = Vote.loved.where(submission_id: presentation.hunt.submissions.found.select(:id)).group(:submission_id).count
      id = loves.max_by { |submission_id, count| [count, -submission_id] }&.first
      @most_loved = id && presentation.submissions.find(id)
    end

    def love_count
      most_loved.votes.count(&:loved?)
    end
  end
end
