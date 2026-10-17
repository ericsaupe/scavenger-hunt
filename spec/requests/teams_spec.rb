# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Teams" do
  def queries_for(path)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
    count
  end

  def find(team, item)
    team.submissions.find_by(item:).photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
  end

  it "fills in a submission row for any item the team is missing before it renders the checklist" do
    hunt = create(:hunt)
    team = create(:team, hunt:)
    item = hunt.items.last
    team.submissions.find_by(item:).destroy!

    get "/scavenger_hunts/#{hunt.code}/teams/#{team.id}"

    expect(response).to have_http_status(:ok)
    submission = team.submissions.find_by(item:)
    expect(submission).to be_present
    expect(response.body).to include("submission_#{submission.id}_photo")
    expect(response.body).not_to include('id="new_submission"')
  end

  it "offers a fresh critter for a new team and hands out another on shuffle" do
    hunt = create(:hunt)

    get "/scavenger_hunts/#{hunt.code}"
    seed = response.body[/name="avatar_seed"[^>]*value="(\h{16})"/, 1]
    expect(seed).to be_present
    expect(response.body).to include(Avatar.for(:team, seed))

    get "/scavenger_hunts/#{hunt.code}/teams/avatar", headers: {"Turbo-Frame" => "new_team_avatar"}
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('<turbo-frame id="new_team_avatar">')
    shuffled = response.body[/name="avatar_seed"[^>]*value="(\h{16})"/, 1]
    expect(shuffled).to be_present
    expect(shuffled).not_to eq(seed)

    post "/scavenger_hunts/#{hunt.code}/teams", params: {name: "Owls", avatar_seed: shuffled}
    team = hunt.teams.find_by!(name: "Owls")
    expect(team.avatar_seed).to eq(shuffled)
    expect(response).to redirect_to("/scavenger_hunts/#{hunt.code}/teams/#{team.id}")

    follow_redirect!
    expect(response.body).to include(%(src="#{team.avatar_url}" width="48" height="48" loading="lazy" alt="" data-testid="team-avatar" class="avatar-img"))
  end

  it "renders the checklist with the same number of queries however many items there are" do
    hunt = create(:hunt)
    team = create(:team, hunt:)
    find(team, hunt.items.first)
    path = "/scavenger_hunts/#{hunt.code}/teams/#{team.id}"
    get path
    few = queries_for(path)

    category = create(:category, hunt:)
    create_list(:item, 4, category:)
    hunt.items.reload.each { |item| team.submissions.find_or_create_by!(item:) }
    hunt.items.last(3).each { |item| find(team, item) }
    many = queries_for(path)

    expect(response).to have_http_status(:ok)
    expect(response.body.scan('data-testid="preview"').size).to eq(4)
    expect(many).to eq(few)
  end
end
