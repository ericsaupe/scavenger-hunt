# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Videos", :test_queue_adapter do
  let(:hunt) { create(:hunt) }
  let(:team) { create(:team, hunt:) }
  let(:item) { hunt.items.first }

  it "shows the video as processing until the playable version is ready" do
    submission = team.submissions.find_by(item:)
    submission.photo.attach(io: Rails.root.join("spec/fixtures/video.mp4").open, filename: "clip.mp4")

    visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"

    within("li[data-found]") do
      expect(page).to have_text("Processing video")
      expect(page).to have_css(".loading-spinner")
      expect(page).not_to have_css("img")
    end
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)

    TranscodeVideoJob.perform_now(submission)

    within("li[data-found]") do
      expect(page).not_to have_text("Processing video")
      expect(page).to have_css("img[src*='/rails/active_storage/representations/']")
    end
    find("[data-testid='preview']", text: item.name).click
    expect(page).to have_css("dialog[open] video[src*='/rails/active_storage/blobs/'][poster*='/rails/active_storage/representations/']")
  end

  it "takes a video back with a banner when it turns out to be too long", ffprobe_duration: 31 do
    submission = team.submissions.find_by(item:)
    submission.photo.attach(io: Rails.root.join("spec/fixtures/video.mp4").open, filename: "clip.mp4")

    visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
    expect(page).to have_css("li[data-found]", text: "Processing video")
    expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)

    TranscodeVideoJob.perform_now(submission)

    expect(page).to have_text("Videos must be 30 seconds or shorter. Try a shorter clip.")
    expect(page).not_to have_css("li[data-found]")
    expect(page).to have_css("label", text: item.name)
    expect(submission.reload.photo).not_to be_attached
  end
end
