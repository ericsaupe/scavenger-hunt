# frozen_string_literal: true

class TeamsController < ApplicationController
  def create
    hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
    team = if params[:team_id]
             hunt.teams.find(params[:team_id])
           else
             hunt.teams.create!(name: params[:name])
           end

    redirect_to hunt_team_path(hunt.code, team)
  end

  def show
    @hunt = Hunt.find_by!(code: params[:hunt_code].upcase)
    @team = @hunt.teams.find(params[:id])
  end
end
