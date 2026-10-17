# frozen_string_literal: true

class TeamsController < ApplicationController
  def show
    @hunt = Hunt.includes(categories: :items).find_by!(code: params[:hunt_code].upcase)
    @team = @hunt.teams.find(params[:id])
    @submissions = @team.submissions.includes({item: :category}, photo_attachment: :blob, playback_attachment: :blob).index_by(&:item_id)
    cookies.permanent.signed[:last_team_id] = @team.id unless request.headers["X-Sec-Purpose"] == "prefetch"
  end

  def create
    team = if params[:team_id].present?
      hunt.teams.find(params[:team_id])
    elsif params[:name].present?
      hunt.start_a_new_team(params[:name], avatar_seed: params[:avatar_seed])
    else
      flash[:error] = "Please select a team or enter a team name"
      redirect_to hunt_path(hunt.code) and return
    end

    redirect_to hunt_team_path(hunt.code, team)
  end

  def avatar
    @hunt = hunt
    @seed = Team.new_avatar_seed
  end

  def pending_uploads
    return head :bad_request if params[:client].blank?

    team = hunt.teams.find(params[:id])
    team.report_pending_uploads(params[:client].to_s.first(64), params[:count].to_i)
    head :no_content
  end

  private

  def hunt
    @hunt ||= Hunt.find_by!(code: params[:hunt_code].upcase)
  end
end
