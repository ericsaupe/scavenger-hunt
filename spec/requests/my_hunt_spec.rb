# frozen_string_literal: true

require "rails_helper"

RSpec.describe "My hunt" do
  def team_path(team)
    "/scavenger_hunts/#{team.hunt.code}/teams/#{team.id}"
  end

  it "sends a viewer who has not joined a hunt to the join page" do
    get "/my_hunt"

    expect(response).to redirect_to("/scavenger_hunts/join")
  end

  it "sends a viewer back to the team they most recently joined" do
    earlier_team = create(:team)
    team = create(:team)
    get team_path(earlier_team)
    get team_path(team)

    get "/my_hunt"

    expect(response).to redirect_to(team_path(team))
  end

  it "ignores a forged team id so the cookie cannot reveal hunt codes" do
    team = create(:team)
    cookies[:last_team_id] = team.id

    get "/my_hunt"

    expect(response).to redirect_to("/scavenger_hunts/join")
  end

  it "sends a viewer whose team no longer exists to the join page" do
    team = create(:team)
    get team_path(team)
    team.hunt.destroy!

    get "/my_hunt"

    expect(response).to redirect_to("/scavenger_hunts/join")
  end
end
