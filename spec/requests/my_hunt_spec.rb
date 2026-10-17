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

  it "does not remember a team whose page was only prefetched" do
    team = create(:team)
    prefetched_team = create(:team)
    get team_path(team)
    get team_path(prefetched_team), headers: {"X-Sec-Purpose" => "prefetch"}

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

  it "opens the named hunt's team page when that is where the viewer last was" do
    team = create(:team)
    get team_path(team)

    get "/my_hunt?hunt=#{team.hunt.code.downcase}"

    expect(response).to redirect_to(team_path(team))
  end

  it "sends a viewer who last played a different hunt to the named hunt's team picker" do
    team = create(:team)
    other_hunt = create(:hunt)
    get team_path(team)

    get "/my_hunt?hunt=#{other_hunt.code}"

    expect(response).to redirect_to("/scavenger_hunts/#{other_hunt.code}")
  end

  it "falls back to the usual routing when the named hunt does not exist" do
    team = create(:team)
    get team_path(team)

    get "/my_hunt?hunt=NOPE"

    expect(response).to redirect_to(team_path(team))
  end
end
