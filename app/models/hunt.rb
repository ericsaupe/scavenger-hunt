# frozen_string_literal: true

require "zip"

class Hunt < ApplicationRecord
  include BCrypt

  LATE_UPLOAD_GRACE = 15.minutes
  STARTING_SOON_LEAD = 5.minutes
  LEAD_CHANGE_INTERVAL = 5.minutes
  PLAYBACK_COMMANDS = %w[play pause replay mute unmute].freeze
  SCREEN_CHAT_TTL = 60.seconds
  SCREEN_CHAT_LIMIT = 8

  has_many :categories, dependent: :destroy
  has_many :items, through: :categories
  has_many :submissions, through: :items
  has_many :messages, dependent: :destroy
  has_many :teams, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy
  belongs_to :victory_item, class_name: "Item", optional: true

  has_one_attached :archive

  enum :screen_chat, %w[off all announcements].index_by(&:itself), prefix: true, scopes: false

  before_save :generate_code, if: :new_record?
  after_commit :schedule_starting_soon_notification, if: :saved_change_to_starts_at?
  after_commit :schedule_results_notification, if: :saved_change_to_ends_at?

  def start_a_new_team(team_name, avatar_seed: nil)
    ActiveRecord::Base.transaction do
      team = teams.find_or_create_by(name: team_name) { |new_team| new_team.avatar_seed = avatar_seed }
      # rubocop:disable Rails/SkipsModelValidations
      # Yeah, probably not the best but it's nicer on the frontend and the
      # joint updates if all the records are created here.
      current_time = Time.current
      Submission.upsert_all(
        items.map do |item|
          {
            item_id: item.id,
            team_id: team.id,
            created_at: current_time,
            updated_at: current_time
          }
        end
      )
      # rubocop:enable Rails/SkipsModelValidations
    end
    teams.find_by!(name: team_name)
  end

  def in_progress?
    !ended? && !upcoming?
  end

  def upcoming?
    starts_at && starts_at > Time.current
  end

  def ended?
    ends_at && ends_at < Time.current
  end

  def accepts_photo_captured_at?(captured_at)
    return true unless ended?

    captured_at.present? && captured_at <= ends_at && Time.current <= ends_at + LATE_UPLOAD_GRACE
  end

  def in_grace_window?
    ended? && Time.current <= ends_at + LATE_UPLOAD_GRACE
  end

  def pending_upload_count
    Team.pending_uploads_for(teams)
  end

  def timer?
    starts_at.present? || ends_at.present?
  end

  def results
    found = Submission.found.joins(item: :category).where(team: teams)
    total_scores = found.group(:team_id).sum("categories.points")
    scores = found.with_points.group(:team_id).sum("categories.points")
    found_counts = found.group(:team_id).count

    ranked = teams.map do |team|
      score = scores.fetch(team.id, 0)
      total_score = total_scores.fetch(team.id, 0)
      [team, {team_id: team.id, name: team.name, team:, score:, total_score:, deductions: total_score - score, submissions: found_counts.fetch(team.id, 0)}]
    end.sort_by { |_, result| result[:score] }.reverse

    winner, winning_result = ranked.first
    winning_result[:victory_photo_url] = winner.victory_photo_url(victory_item_id:) if winner
    ranked.map(&:last)
  end

  def leader
    ranked = results
    top, runner_up = ranked.first(2)
    return if top.nil? || top[:score].zero? || runner_up&.dig(:score) == top[:score]

    [teams.find(top[:team_id]), top[:score]]
  end

  def results_locked?
    (lock_results && ends_at && ends_at > Time.current) || (lock_password.present? && !password_entered)
  end

  def leaderboard_visible?
    !results_locked? && (lock_password.blank? || password_entered_for_leaderboard)
  end

  def password
    @password ||= lock_password
  end

  def password=(new_password)
    @password = Password.create(new_password)
    self.lock_password = @password
  end

  def create_archive_file
    FileUtils.mkdir_p(Rails.root.join("tmp"))
    zipfile_name = Rails.root.join("tmp", "archive-#{id}.zip")
    FileUtils.rm_f(zipfile_name)

    Zip::OutputStream.open(zipfile_name) do |zip|
      teams.find_each do |team|
        folder = [archive_path_segment(name), archive_path_segment(team.name)].join("/")
        team.submissions.found.includes(:item, photo_attachment: :blob).order(:id).each do |submission|
          filename = [archive_path_segment(submission.item.name), submission.photo_extension].join

          zip.put_next_entry("#{folder}/#{filename}", "", Zip::ExtraField.new, Zip::Entry::STORED)
          submission.photo.download { |chunk| zip.write(chunk) }
        end
      end
    end

    File.open(zipfile_name) { |file| archive.attach(io: file, filename: "#{name}.zip") }
  ensure
    FileUtils.rm_f(zipfile_name) if zipfile_name
  end

  def presentation
    @presentation ||= Presentation.new(self)
  end

  def presenter_stream
    "hunt_presenter_#{id}"
  end

  def chat_stream
    "hunt_chat_#{id}"
  end

  def chat_list_id
    "hunt_chat_#{id}"
  end

  def chat_composer_id
    "chat_composer_#{id}"
  end

  def chat_notice_id
    "chat_notice_#{id}"
  end

  def chat_team_count_id
    "chat_team_count_#{id}"
  end

  def chat_available?
    chat_enabled? && Flipper.enabled?(:chat)
  end

  def viewer_token(user_id)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.key_generator.generate_key("chat viewer"), "#{id}:#{user_id}")
  end

  def latest_announcement
    messages.announcements.visible.order(:id).last
  end

  def recent_messages(before: nil)
    scope = messages.includes(:team).order(id: :desc)
    scope = scope.where(id: ...before) if before
    scope.limit(Message::PAGE_SIZE).to_a.reverse
  end

  def screen_chat_visible?
    chat_available? && !screen_chat_off?
  end

  def screen_chat_messages
    scope = messages.visible.includes(:team).where(created_at: SCREEN_CHAT_TTL.ago..)
    scope = scope.announcements if screen_chat_announcements?
    scope.order(id: :desc).limit(SCREEN_CHAT_LIMIT).to_a.reverse
  end

  def chatter_count
    messages.visible.distinct.count(:user_id)
  end

  def earlier_messages?(message)
    messages.where(id: ...message.id).exists?
  end

  def present!(slide_key)
    update!(presentation_slide: slide_key, presentation_playback: "paused", playback_started_at: nil)
    broadcast_presentation_update
    announce_show!
  end

  def playback!(command)
    case command
    when "play" then assign_attributes(presentation_playback: "playing", playback_started_at: Time.current)
    when "pause" then assign_attributes(presentation_playback: "paused")
    when "replay" then assign_attributes(presentation_playback: "playing", playback_started_at: Time.current, playback_version: playback_version + 1)
    when "mute" then assign_attributes(presentation_muted: true)
    when "unmute" then assign_attributes(presentation_muted: false)
    else raise ArgumentError, "unknown playback command #{command.inspect}"
    end
    save!
    broadcast_presentation_update
  end

  def screen_chat!(mode)
    update!(screen_chat: mode)
    broadcast_presentation_update
  end

  def hand_remote_to!(user_id)
    update!(remote_holder_id: user_id)
    broadcast_presentation_update
    announce_show!
  end

  def schedule_notifications
    schedule_starting_soon_notification
    schedule_results_notification
  end

  def announce_show!
    return if show_announced_at

    announced = with_lock do
      next false if show_announced_at

      update!(show_announced_at: Time.current)
    end
    ShowStartingJob.perform_later(self) if announced
  end

  def playing?
    presentation_playback == "playing"
  end

  def broadcast_presentation_update
    broadcast_refresh_to(presenter_stream)
  end

  def owner_password_matches?(candidate)
    lock_password.blank? || password == candidate
  end

  def owner?(user_id)
    user_id.present? && owner_id == user_id
  end

  def remote_holder?(user_id)
    user_id.present? && remote_holder_id == user_id
  end

  def remote_held?
    remote_holder_id.present?
  end

  def organizer?(user_id)
    owner?(user_id) || remote_holder?(user_id)
  end

  private

  def schedule_starting_soon_notification
    return if starts_at.nil? || starts_at - STARTING_SOON_LEAD <= Time.current

    HuntStartingSoonJob.set(wait_until: starts_at - STARTING_SOON_LEAD).perform_later(self, starts_at)
  end

  def schedule_results_notification
    return if ends_at.nil? || ends_at + LATE_UPLOAD_GRACE <= Time.current

    HuntResultsReadyJob.set(wait_until: ends_at + LATE_UPLOAD_GRACE).perform_later(self, ends_at)
  end

  ##
  # Generate a code to be used for better UX. If one is already set double check that it is unique
  # and if it's not then generate a new one.
  #
  def generate_code(character_count: 5)
    new_code = code&.upcase || ("A".."Z").to_a.sample(character_count).join
    while Hunt.find_by(code: new_code).present?
      new_code = ("A".."Z").to_a.sample(character_count).join
    end
    self.code = new_code
  end

  def archive_path_segment(name)
    name.tr('"', "'").gsub(/[\/\\:*?<>|[:cntrl:]]/, "-").strip
  end
end
