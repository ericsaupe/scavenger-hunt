# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Presenter" do
  let(:hunt) { create(:hunt, owner_id: "host") }
  let(:team) { create(:team, hunt:) }

  before do
    @video = create(:video_submission, item: hunt.items.first, team:)
    @photo = create(:photo_submission, item: hunt.items.second, team:)
    hunt.update!(presentation_submission: @video)
  end

  def video_paused?
    page.evaluate_script("document.querySelector('video').paused")
  end

  def video_error
    page.evaluate_script("document.querySelector('video').error?.code")
  end

  it "shows the slide without controls on the big screen and follows the remote" do
    visit "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

    expect(page).to have_css("[data-testid='progress']", text: "Video 1 of 2")
    expect(page).to have_css("video:not([autoplay])[playsinline][preload='metadata']")
    expect(page).not_to have_button("Previous")
    expect(page).not_to have_css("[data-testid='vote-menu']")
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)
    expect(video_paused?).to be(true)
    expect(video_error).to be_nil

    hunt.reload.playback!("play")
    expect(page).to have_css("[data-playback-state-value='playing']")
    expect(video_paused?).to be(false)

    hunt.reload.playback!("pause")
    expect(page).to have_css("[data-playback-state-value='paused']")
    expect(video_paused?).to be(true)

    hunt.reload.present!(@photo.id)
    expect(page).to have_css("[data-testid='progress']", text: "Photo 2 of 2")
    expect(page).to have_css("img#submission_#{@photo.id}_photo")
  end

  it "never starts the video on a watcher's phone" do
    hunt.update!(presentation_playback: "playing", playback_started_at: Time.current)

    visit "/scavenger_hunts/#{hunt.code}/presenter"

    expect(page).to have_css("video[controls]")
    expect(page).to have_css("button[aria-label='Play video']")
    expect(page).to have_css("[data-testid='vote-menu']")
    expect(video_paused?).to be(true)
  end

  it "hands the remote to whoever takes it" do
    visit "/scavenger_hunts/#{hunt.code}/presenter"
    expect(page).to have_text("Someone else has the remote")

    click_on "Take the remote"

    expect(page).to have_current_path("/scavenger_hunts/#{hunt.code}/presenter/remote")
    expect(page).to have_button("Next")
    expect(page).to have_button("Play on the big screen")
    expect(hunt.reload.owner_id).to be_present

    click_on "Next"
    expect(page).to have_css("[data-testid='progress']", text: "Photo 2 of 2")
    expect(page).to have_current_path("/scavenger_hunts/#{hunt.code}/presenter/remote")
    expect(hunt.reload.presentation_submission).to eq(@photo)
  end
end
