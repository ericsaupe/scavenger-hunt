# frozen_string_literal: true

require "zip"

class Hunt < ApplicationRecord
  include BCrypt

  has_many :categories, dependent: :destroy
  has_many :items, through: :categories
  has_many :submissions, through: :items
  has_many :messages, dependent: :destroy
  has_many :teams, dependent: :destroy
  belongs_to :presentation_submission, class_name: "Submission", optional: true
  belongs_to :victory_item, class_name: "Item", optional: true

  has_one_attached :archive

  before_save :generate_code, if: :new_record?

  def start_a_new_team(team_name)
    ActiveRecord::Base.transaction do
      team = teams.find_or_create_by(name: team_name)
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

  def timer?
    starts_at.present? || ends_at.present?
  end

  def results
    teams.map do |team|
      {
        name: team.name,
        score: team.score,
        total_score: team.total_score,
        deductions: team.total_score - team.score,
        submissions: team.submissions.with_attached_photo.size,
        victory_photo_url: team.victory_photo_url(victory_item_id:)
      }
    end.sort_by { |team| team[:score] }.reverse
  end

  def results_locked?
    (lock_results && ends_at && ends_at > Time.current) || (lock_password.present? && !password_entered)
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

    Zip::File.open(zipfile_name, create: true) do |zipfile|
      teams.find_each do |team|
        folder = [name, team.name].join("/")
        team.submissions.with_attached_photo.find_each do |submission|
          extension = Rack::Mime::MIME_TYPES.invert[submission.photo.content_type]
          filename = [submission.item.name, extension].join

          submission.photo.open(tmpdir: Rails.root.join("tmp")) do |file|
            filepath = file.path
            zipfile.add("#{folder}/#{filename}", filepath)
            zipfile.commit
          end
        end
      end
    end

    archive.attach(io: File.open(zipfile_name), filename: "#{name}.zip")
  end

  def broadcast_presentation_update(submission)
    broadcast_replace_to("hunt_presenter_#{id}", target: "current_submission", partial: "submissions/submission_presenter", locals: {submission: submission})
  end

  def owner?(user_id)
    owner_id == user_id
  end

  private

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
end
