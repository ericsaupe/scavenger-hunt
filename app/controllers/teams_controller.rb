# frozen_string_literal: true

class TeamsController < ApplicationController
  def show
    @team = hunt.teams.find(params[:id])
    @submissions = @team.submissions.includes(:photo_attachment)
  end

  def create
    team = if params[:team_id].present?
      hunt.teams.find(params[:team_id])
    elsif params[:name].present?
      hunt.start_a_new_team(params[:name])
    else
      flash[:error] = "Please select a team or enter a team name"
      redirect_to hunt_path(hunt.code) and return
    end

    redirect_to hunt_team_path(hunt.code, team)
  end

  private

  def hunt
    @hunt ||= Hunt.find_by!(code: params[:hunt_code].upcase)
  end
end
