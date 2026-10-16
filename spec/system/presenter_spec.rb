# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Presenter" do
  let(:hunt) { create(:hunt, owner_id: "host") }
  let(:team) { create(:team, hunt:) }

  before do
    @video = create(:video_submission, item: hunt.items.first, team:)
    @photo = create(:photo_submission, item: hunt.items.second, team:)
    hunt.update!(presentation_slide: "submission:#{@video.id}")
  end

  def video_paused?
    page.evaluate_script("document.querySelector('video').paused")
  end

  def video_error
    page.evaluate_script("document.querySelector('video').error?.code")
  end

  it "shows the slide without controls on the big screen and follows the remote" do
    visit "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

    expect(page).to have_css("[data-testid='progress']", text: "Video 2 of 5")
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

    hunt.reload.present!("submission:#{@photo.id}")
    expect(page).to have_css("[data-testid='progress']", text: "Photo 4 of 5")
    expect(page).to have_css("img#submission_#{@photo.id}_photo")
  end

  it "offers a tap to enable sound when the browser blocks audible playback" do
    visit "/scavenger_hunts/#{hunt.code}/presenter?screen=big"
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)
    page.execute_script(<<~JS)
      const play = HTMLMediaElement.prototype.play
      HTMLMediaElement.prototype.play = function () {
        if (!this.muted && !window.userGestureSeen) {
          return Promise.reject(new DOMException("blocked", "NotAllowedError"))
        }
        return play.call(this)
      }
      document.addEventListener("click", () => { window.userGestureSeen = true }, true)
    JS
    expect(page).not_to have_button("Tap to enable sound")

    hunt.reload.playback!("play")
    hunt.reload.playback!("unmute")
    expect(page).to have_button("Tap to enable sound")
    expect(page.evaluate_script("document.querySelector('video').muted")).to be(true)
    expect(video_paused?).to be(false)

    click_on "Tap to enable sound"
    expect(page).not_to have_button("Tap to enable sound")
    expect(page.evaluate_script("document.querySelector('video').muted")).to be(false)
    expect(video_paused?).to be(false)

    hunt.reload.playback!("pause")
    expect(page).to have_css("[data-playback-state-value='paused']")
    expect(video_paused?).to be(true)
  end

  it "never starts the video on a watcher's phone" do
    hunt.update!(presentation_playback: "playing", playback_started_at: Time.current)

    visit "/scavenger_hunts/#{hunt.code}/presenter"

    expect(page).to have_css("video[controls]")
    expect(page).to have_css("button[aria-label='Play video']")
    expect(page).to have_css("[data-testid='vote-menu']")
    expect(video_paused?).to be(true)
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)

    find("button[aria-label='Play video']").click
    expect(page).not_to have_css("button[aria-label='Play video']")
    expect(video_paused?).to be(false)

    hunt.reload.playback!("replay")
    expect(page).to have_css("[data-playback-version-value='1']")
    expect(page).not_to have_css("button[aria-label='Play video']")
    expect(video_paused?).to be(false)
  end

  it "hands the remote to whoever takes it" do
    visit "/scavenger_hunts/#{hunt.code}/presenter"
    expect(page).to have_text("Someone else has the remote")

    click_on "Take the remote"

    expect(page).to have_current_path("/scavenger_hunts/#{hunt.code}/presenter/remote")
    expect(page).to have_button("Next")
    expect(page).to have_button("Play on the big screen")
    expect(hunt.reload.owner_id).to be_present
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)

    click_on "Next"
    expect(page).to have_css("[data-testid='progress']", text: "Item 3 of 5")
    expect(page).to have_current_path("/scavenger_hunts/#{hunt.code}/presenter/remote")
    expect(hunt.reload.presentation_slide).to eq("item:#{hunt.items.second.id}")
  end

  it "opens each item with a title card and closes with the winner" do
    hunt.update!(presentation_slide: nil)
    create(:vote, submission: @photo, value: "love")
    points = hunt.categories.first.points

    using_session(:big_screen) do
      visit "/scavenger_hunts/#{hunt.code}/presenter?screen=big"
      expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)
      expect(page).to have_css("[data-testid='progress']", text: "Item 1 of 5")
      expect(page).to have_css("[data-testid='title-card']", text: /next up/i)
      expect(page).to have_css("[data-testid='title-card']", text: hunt.items.first.name)
      expect(page).to have_css("[data-testid='title-card-summary']", text: "Found by 1 of 1 team, #{points} points each")
      expect(page).to have_css("[data-testid='title-card'] figure img, [data-testid='title-card'] figure svg")
    end

    visit "/scavenger_hunts/#{hunt.code}/presenter"
    click_on "Take the remote"
    expect(page).to have_css("[data-testid='current-item']", text: hunt.items.first.name)
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)

    click_on "Next"
    expect(page).to have_css("[data-testid='progress']", text: "Video 2 of 5")
    using_session(:big_screen) do
      expect(page).to have_css("[data-testid='progress']", text: "Video 2 of 5")
      expect(page).to have_css("video")
    end

    click_on "Next"
    expect(page).to have_css("[data-testid='progress']", text: "Item 3 of 5")
    using_session(:big_screen) do
      expect(page).to have_css("[data-testid='title-card']", text: hunt.items.second.name)
    end

    click_on "Next"
    expect(page).to have_css("[data-testid='progress']", text: "Photo 4 of 5")
    using_session(:big_screen) do
      expect(page).to have_css("img#submission_#{@photo.id}_photo")
      expect(page).to have_css("[data-testid='love-count']", text: "1 love")
      expect(page).to have_css("[data-testid='flag-count']", text: "0 of 1 flags")
    end

    using_session(:watcher) do
      visit "/scavenger_hunts/#{hunt.code}/presenter"
      expect(page).to have_css("[data-vote-submission-id-value='#{@photo.id}']")
      find("[data-testid='vote-menu-love-button']").click
      expect(page).to have_css("[data-vote-value-value='love']")
    end
    using_session(:big_screen) do
      expect(page).to have_css("[data-testid='reaction'][data-reaction-kind='love']")
      expect(page).to have_css("[data-testid='love-count']", text: "2 loves")
      expect(page).to have_no_css("[data-testid='reaction']", wait: 5)
    end
    using_session(:watcher) do
      click_on "Flag it"
      expect(page).to have_button("Flagged")
    end
    using_session(:big_screen) do
      expect(page).to have_css("[data-testid='reaction'][data-reaction-kind='flag']")
      expect(page).to have_css("[data-testid='flag-count']", text: "1 of 1 flags")
      expect(page).to have_css("[data-testid='doesnt-count']", text: /doesn't count/i)
      expect(page).to have_css("[data-testid='love-count']", text: "1 love")
    end

    click_on "Next"
    expect(page).to have_css("[data-testid='progress']", text: "Finale 5 of 5")
    expect(page).to have_css("[data-testid='current-item']", text: "First place")
    using_session(:big_screen) do
      expect(page).to have_css("[data-testid='finale']", text: /first place/i)
      expect(page).to have_css("[data-testid='winner-name']", text: team.name)
      expect(page).to have_css("[data-testid='finale']", text: "#{team.score} points")
      expect(page).to have_css("[data-testid='most-loved']", text: "1 love")
      expect(page).to have_css("[data-testid='confetti'] .confetti", visible: :all, minimum: 10)
      expect(page).to have_link("Results", href: "/scavenger_hunts/#{hunt.code}/results")
    end

    click_on "Next"
    expect(page).to have_css("[data-testid='progress']", text: "Item 1 of 5")
  end

  it "lets a watcher browse earlier slides and come back to live" do
    hunt.update!(presentation_slide: "submission:#{@photo.id}")

    visit "/scavenger_hunts/#{hunt.code}/presenter"
    expect(page).to have_css("[data-testid='live-pill']", text: "Live")
    expect(page).to have_css("[data-testid='progress']", text: "Photo 4 of 5")
    expect(page).not_to have_link("Back to live")
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)

    click_on "Previous"
    expect(page).to have_css("[data-testid='live-pill']", text: "Browsing")
    expect(page).to have_css("[data-testid='progress']", text: "Item 3 of 5")
    expect(page).to have_css("[data-testid='title-card']", text: hunt.items.second.name)
    expect(page).to have_link("Back to live, now on 4 of 5")

    click_on "Previous"
    expect(page).to have_css("[data-testid='progress']", text: "Video 2 of 5")
    expect(page).to have_css("[data-vote-submission-id-value='#{@video.id}']")

    find("[data-testid='vote-menu-love-button']").click
    expect(page).to have_css("[data-vote-submission-id-value='#{@video.id}'][data-vote-value-value='love']")
    expect(@video.votes.loved.count).to eq(1)
    expect(@photo.votes.count).to eq(0)

    hunt.reload.present!("finale")
    expect(page).to have_link("Back to live, now on 5 of 5")
    expect(page).to have_css("[data-testid='live-pill']", text: "Browsing")
    expect(page).to have_css("[data-testid='progress']", text: "Video 2 of 5")

    click_on "Back to live, now on 5 of 5"
    expect(page).to have_css("[data-testid='live-pill']", text: "Live")
    expect(page).to have_css("[data-testid='progress']", text: "Finale 5 of 5")
    expect(page).to have_css("[data-testid='finale']", text: /first place/i)
    expect(page).not_to have_link("Back to live")

    hunt.reload.present!("submission:#{@video.id}")
    expect(page).to have_css("[data-testid='progress']", text: "Video 2 of 5")
    expect(page).to have_css("[data-testid='live-pill']", text: "Live")
  end
end
