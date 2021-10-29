# frozen_string_literal: true

class Hunt < ApplicationRecord
  has_many :categories, dependent: :destroy
  has_many :items, through: :categories
  has_many :teams, dependent: :destroy

  before_save :generate_code, if: :new_record?

  def start_a_new_team(_team_name)
    ActiveRecord::Base.transaction do
      team = teams.create!(name: params[:name])
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
    teams.find_by!(name: params[:name])
  end

  private

  ##
  # Generate a code to be used for better UX. If one is already set double check that it is unique
  # and if it's not then generate a new one.
  #
  def generate_code(character_count: 4)
    new_code = code&.upcase || ('A'..'Z').to_a.sample(character_count).join
    while Hunt.find_by(code: new_code).present?
      new_code = ('A'..'Z').to_a.sample(character_count).join
    end
    self.code = new_code
  end
end
