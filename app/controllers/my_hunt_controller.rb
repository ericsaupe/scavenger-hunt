# frozen_string_literal: true

class MyHuntController < ApplicationController
  def show
    team = Team.includes(:hunt).find_by(id: cookies.signed[:last_team_id])
    hunt = Hunt.find_by(code: params[:hunt].to_s.upcase) if params[:hunt].present?

    if hunt && team&.hunt_id != hunt.id
      redirect_to hunt_path(hunt.code)
    elsif team
      redirect_to hunt_team_path(team.hunt.code, team)
    else
      redirect_to join_hunts_path
    end
  end
end
