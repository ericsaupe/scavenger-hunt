# frozen_string_literal: true

class TeamsController < ApplicationController
  def create
    team = if params[:team_id].present?
             hunt.teams.find(params[:team_id])
           else
             hunt.start_a_new_team(params[:name])
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
