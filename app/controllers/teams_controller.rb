# frozen_string_literal: true

class TeamsController < ApplicationController
  def create
    ActiveRecord::Base.transaction do
      team = if params[:team_id].present?
               hunt.teams.find(params[:team_id])
             else
               hunt.teams.create!(name: params[:name])
             end

      # Yeah, probably not the best but it's nicer on the frontend and the
      # joint updates if all the records are created here.
      current_time = Time.current
      Submission.upsert_all!(
        hunt.items.map do |item|
          {
            item_id: item.id,
            team_id: team.id,
            created_at: current_time,
            updated_at: current_time
          }
        end
      )
    end

    redirect_to hunt_team_path(hunt.code, team)
  end

  def show
    @team = hunt.teams.find(params[:id])
    @submissions = @team.submissions
  end

  private

  def hunt
    @hunt ||= Hunt.find_by!(code: params[:hunt_code].upcase)
  end
end
