# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Avatars" do
  let(:hunt) { create(:hunt) }
  let!(:team) { create(:team, hunt:, name: "Blue Bandits") }

  def avatar_seed_field
    find("input[name='avatar_seed']", visible: :hidden).value
  end

  it "shows each team's critter in the team list and lets a new team shuffle theirs before joining" do
    visit "/scavenger_hunts/#{hunt.code}"

    expect(page).to have_css("[data-testid='team-avatar'][src='#{team.avatar_url}'][width='40'][height='40'][loading='lazy']")
    expect(page).to have_css("source[media='(prefers-reduced-motion: reduce)'][srcset='#{team.avatar_url(still: true)}']", visible: :all)
    first_seed = avatar_seed_field
    expect(page).to have_css("[data-testid='new-team-avatar'][src='#{Avatar.for(:team, first_seed)}']")

    click_on "Shuffle"
    expect(page).not_to have_css("[data-testid='new-team-avatar'][src='#{Avatar.for(:team, first_seed)}']")
    seed = avatar_seed_field
    expect(seed).not_to eq(first_seed)
    expect(page).to have_css("[data-testid='new-team-avatar'][src='#{Avatar.for(:team, seed)}']")

    fill_in "Or start a new team", with: "Red Rockets"
    click_on "Join the hunt"
    expect(page).to have_css("h1", text: "Red Rockets")
    rockets = hunt.teams.find_by!(name: "Red Rockets")
    expect(rockets.avatar_seed).to eq(seed)
    expect(page).to have_css("[data-testid='team-avatar'][src='#{rockets.avatar_url}']")
    expect(page.evaluate_script("document.querySelector(\"[data-testid='team-avatar']\").complete")).to be(true)
    expect(a_request(:get, %r{critters/svg}).with(query: hash_including("seed" => Avatar.digest("team", seed)))).to have_been_made.once
  end

  it "puts critters on the leaderboard, the finale and the remote, with a DiceBear credit" do
    create(:photo_submission, item: hunt.items.first, team:)
    runner_up = create(:team, hunt:, name: "Red Rockets")
    hunt.update!(presentation_slide: "finale", owner_id: "host")

    visit "/scavenger_hunts/#{hunt.code}/results"
    expect(page).to have_css("[data-testid='winner'] [data-testid='team-avatar'][src='#{team.avatar_url}']")
    expect(page).to have_css("table [data-testid='team-avatar'][src='#{runner_up.avatar_url}']")
    expect(page).to have_css("[data-testid='avatar-credit']", text: "DiceBear")
    expect(page).to have_link("DiceBear", href: "https://www.dicebear.com")

    visit "/scavenger_hunts/#{hunt.code}/presenter?screen=big"
    expect(page).to have_css("[data-testid='finale'] [data-testid='team-avatar'][src='#{team.avatar_url}']")
    expect(page).to have_css("[data-testid='runners-up'] [data-testid='team-avatar'][src='#{runner_up.avatar_url}']")

    page.driver.browser.manage.add_cookie(name: "user_id", value: "host")
    visit "/scavenger_hunts/#{hunt.code}/presenter/remote"
    expect(page).to have_css("[data-testid='current-item']", text: "First place")
    expect(page).to have_css("[data-testid='team-avatar'][src='#{team.avatar_url}'][width='20']")
  end
end
