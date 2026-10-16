# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Presentations" do
  let(:hunt) { create(:hunt, owner_id: "owner") }
  let(:items) { hunt.items.order(:id).to_a }
  let(:team) { create(:team, hunt:) }
  let!(:first) { found(items.first) }
  let!(:second) { found(items.second) }
  let!(:third) { found(items.third) }

  def found(item)
    submission = team.submissions.find_by(item:)
    submission.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
    submission
  end

  before do
    cookies[:user_id] = "owner"
    allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_later_to)
  end

  describe "PATCH /presentation" do
    it "refuses anyone without the remote" do
      cookies[:user_id] = "viewer"

      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {submission_id: second.id}, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(hunt.reload.presentation_submission_id).to be_nil
      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_refresh_later_to)
    end

    it "jumps to a slide and broadcasts a single refresh" do
      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {submission_id: second.id}, as: :json

      expect(response).to have_http_status(:no_content)
      expect(hunt.reload.presentation_submission).to eq(second)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_refresh_later_to).with("hunt_presenter_#{hunt.id}", request_id: nil).once
    end

    it "steps forward and wraps around the end" do
      hunt.update!(presentation_submission: third)

      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {direction: "next"}, as: :json

      expect(hunt.reload.presentation_submission).to eq(first)
    end

    it "steps back and wraps around the start" do
      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {direction: "previous"}, as: :json

      expect(hunt.reload.presentation_submission).to eq(third)
    end

    it "pauses playback when the slide changes" do
      hunt.update!(presentation_submission: first, presentation_playback: "playing", playback_started_at: Time.current)

      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {direction: "next"}, as: :json

      expect(hunt.reload).to have_attributes(presentation_submission: second, presentation_playback: "paused", playback_started_at: nil)
    end

    it "ignores a slide that is not part of the show" do
      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {submission_id: third.id + 100}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(hunt.reload.presentation_submission_id).to be_nil
    end
  end

  describe "PATCH /presentation/playback" do
    def playback(action)
      patch "/scavenger_hunts/#{hunt.code}/presentation/playback", params: {playback: {action:}}, as: :json
    end

    it "refuses anyone without the remote" do
      cookies[:user_id] = "viewer"

      playback("play")

      expect(response).to have_http_status(:forbidden)
      expect(hunt.reload.presentation_playback).to eq("paused")
    end

    it "plays, pauses and replays" do
      playback("play")
      expect(response).to have_http_status(:no_content)
      expect(hunt.reload).to have_attributes(presentation_playback: "playing", playback_version: 0)
      expect(hunt.playback_started_at).to be_present

      playback("pause")
      expect(hunt.reload.presentation_playback).to eq("paused")

      playback("replay")
      expect(hunt.reload).to have_attributes(presentation_playback: "playing", playback_version: 1)
      expect(Turbo::StreamsChannel).to have_received(:broadcast_refresh_later_to).exactly(3).times
    end

    it "starts muted and toggles the sound" do
      expect(hunt.presentation_muted).to be(true)

      playback("unmute")
      expect(hunt.reload.presentation_muted).to be(false)

      playback("mute")
      expect(hunt.reload.presentation_muted).to be(true)
    end

    it "rejects unknown commands" do
      playback("rewind")

      expect(response).to have_http_status(:unprocessable_content)
      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_refresh_later_to)
    end
  end

  describe "GET /presenter/remote" do
    it "sends anyone without the remote to the presentation" do
      cookies[:user_id] = "viewer"

      get "/scavenger_hunts/#{hunt.code}/presenter/remote"

      expect(response).to redirect_to("/scavenger_hunts/#{hunt.code}/presenter")
    end

    it "shows the owner the current slide and the slide controls" do
      hunt.update!(presentation_submission: second)

      get "/scavenger_hunts/#{hunt.code}/presenter/remote"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Photo 2 of 3", ERB::Util.html_escape(items.second.name), "Previous", "Next")
      expect(response.body).not_to include("Play on the big screen")
    end

    it "shows the video transport on a video slide" do
      video = create(:video_submission, item: items.first, team: create(:team, hunt:))
      hunt.update!(presentation_submission: video)

      get "/scavenger_hunts/#{hunt.code}/presenter/remote"

      expect(response.body).to include("Video 2 of 4", "Play on the big screen", "Replay", "Sound on")

      hunt.update!(presentation_playback: "playing", presentation_muted: false)
      get "/scavenger_hunts/#{hunt.code}/presenter/remote"

      expect(response.body).to include("Pause", "Sound off")
      expect(response.body).not_to include("Play on the big screen")
    end
  end
end
