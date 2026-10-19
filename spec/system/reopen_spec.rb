# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reopening submissions" do
  let(:hunt) { create(:hunt, ends_at: 30.minutes.ago) }
  let(:team) { create(:team, hunt:, name: "Pumpkin Patrol") }
  let(:items) { hunt.items.order(:id).to_a }

  def viewer_id
    page.driver.browser.manage.cookie_named("user_id")[:value]
  end

  def wait_for_live_updates
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)
    expect(page).not_to have_css("turbo-cable-stream-source:not([connected])", visible: :all)
  end

  def found(item)
    submission = team.submissions.find_by(item:)
    submission.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
  end

  def choose_photo(item)
    attach_file(Rails.root.join("spec/fixtures/test.jpg")) do
      find(:button, text: item.name).click
      click_on "Choose from your photos"
    end
  end

  def timer
    find("#timer_hunt_#{hunt.id}")
  end

  def open_results_as_organizer
    visit "/scavenger_hunts/#{hunt.code}/results"
    hunt.update!(owner_id: viewer_id)
    visit "/scavenger_hunts/#{hunt.code}/results"
  end

  it "lets the organizer reopen submissions, opens every team's list live and closes it again" do
    found(items.second)

    using_session(:team) do
      visit "/scavenger_hunts/#{hunt.code}/teams/#{team.id}"
      clear_upload_queue
      expect(timer).to have_text("Hunt over. No more submissions.")
      expect(page).to have_text("The hunt is over.")
      find("[data-testid='preview']", text: items.second.name).click
      expect(page).not_to have_button("Retake")
      click_on "Done"
      wait_for_live_updates
    end

    open_results_as_organizer
    within("[data-testid='reopen-card']") do
      expect(page).to have_button("Reopen for 10 minutes")
      find("label", text: "Other").click
      fill_in "Minutes", with: "25"
      expect(page).to have_button("Reopen for 25 minutes")
      click_on "Reopen for 25 minutes"
    end

    within("[data-testid='reopened-card']") do
      expect(page).to have_text(/2[45]:\d\d\s+left/)
      expect(page).to have_text("0 photos in since you reopened")
    end
    expect(hunt.reload).to be_reopened

    using_session(:team) do
      expect(page).to have_css("#timer_hunt_#{hunt.id}[data-state='reopened']", text: /Reopened · 2[45]m \d\ds left/)
      expect(page).to have_text("The organizer reopened submissions for a few minutes.")
      expect(page).not_to have_text("The hunt is over.")
      find("[data-testid='preview']", text: items.second.name).click
      expect(page).to have_button("Retake")
      click_on "Done"
      choose_photo(items.first)
      expect(page).to have_css("li[data-found]", count: 2, wait: 10)
    end

    click_on "+ 5 min"
    within("[data-testid='reopened-card']") do
      expect(page).to have_text(/(29|30):\d\d\s+left/)
      expect(page).to have_text("1 photo in since you reopened")
    end
    using_session(:team) do
      expect(timer).to have_text(/Reopened · (29|30)m \d\ds left/)
    end

    click_on "Close now"
    expect(page).to have_css("[data-testid='reopen-card']")
    expect(hunt.reload).not_to be_reopened

    using_session(:team) do
      expect(timer).to have_text("Hunt over. No more submissions.")
      expect(page).to have_text("The hunt is over.")
      expect(page).not_to have_css("fieldset.submission-fieldset:not([disabled])", visible: :all)
    end
  end

  it "puts the organizer's card back once the reopened time runs out" do
    visit "/scavenger_hunts/#{hunt.code}/results"
    hunt.update!(owner_id: viewer_id, reopened_at: Time.current, ends_at: 3.seconds.from_now)
    visit "/scavenger_hunts/#{hunt.code}/results"

    expect(page).to have_css("[data-testid='reopened-card']")
    expect(page).to have_css("[data-testid='reopen-card']", wait: 8)
  end

  it "keeps new teams out but leaves the results a tap away while reopened" do
    hunt.update!(reopened_at: Time.current, ends_at: 10.minutes.from_now)

    visit "/scavenger_hunts/#{hunt.code}"

    expect(timer).to have_text(/Reopened · \d+m \d\ds left/)
    expect(page).not_to have_field("Or start a new team")
    expect(page).to have_link("View results")
  end
end
