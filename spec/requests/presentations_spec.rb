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
    allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)
  end

  describe "PATCH /presentation" do
    it "refuses anyone without the remote" do
      cookies[:user_id] = "viewer"

      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {slide: "submission:#{second.id}"}, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(hunt.reload.presentation_slide).to be_nil
      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_refresh_to)
    end

    it "jumps to a slide and broadcasts a single refresh" do
      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {slide: "submission:#{second.id}"}, as: :json

      expect(response).to have_http_status(:no_content)
      expect(hunt.reload.presentation_slide).to eq("submission:#{second.id}")
      expect(Turbo::StreamsChannel).to have_received(:broadcast_refresh_to).with("hunt_presenter_#{hunt.id}").once
    end

    it "tags the refresh with the Turbo request that caused it so that page skips it" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_to).and_call_original
      allow(ActionCable.server).to receive(:broadcast)

      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {direction: "next"}, headers: {"X-Turbo-Request-Id" => "remote-tap"}, as: :json

      expect(ActionCable.server).to have_received(:broadcast)
        .with("hunt_presenter_#{hunt.id}", a_string_including('action="refresh"', 'request-id="remote-tap"')).once
    end

    it "walks title card, photos and finale in order, wrapping around the end" do
      expected = [
        "item:#{items.first.id}", "submission:#{first.id}",
        "item:#{items.second.id}", "submission:#{second.id}",
        "item:#{items.third.id}", "submission:#{third.id}",
        "finale"
      ]
      expect(hunt.presentation.keys).to eq(expected)

      walked = expected.drop(1).map do
        patch "/scavenger_hunts/#{hunt.code}/presentation", params: {direction: "next"}, as: :json
        hunt.reload.presentation_slide
      end
      expect(walked).to eq(expected.drop(1))

      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {direction: "next"}, as: :json
      expect(hunt.reload.presentation_slide).to eq(expected.first)
    end

    it "steps back and wraps around the start" do
      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {direction: "previous"}, as: :json

      expect(hunt.reload.presentation_slide).to eq("finale")
    end

    it "pauses playback when the slide changes" do
      hunt.update!(presentation_slide: "submission:#{first.id}", presentation_playback: "playing", playback_started_at: Time.current)

      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {direction: "next"}, as: :json

      expect(hunt.reload).to have_attributes(presentation_slide: "item:#{items.second.id}", presentation_playback: "paused", playback_started_at: nil)
    end

    it "refuses the finale while the leaderboard is locked" do
      hunt.update!(lock_password: "hunter2", presentation_slide: "submission:#{third.id}")

      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {slide: "finale"}, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {direction: "next"}, as: :json
      expect(hunt.reload.presentation_slide).to eq("item:#{items.first.id}")
    end

    it "ignores a slide that is not part of the show" do
      patch "/scavenger_hunts/#{hunt.code}/presentation", params: {slide: "submission:#{third.id + 100}"}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(hunt.reload.presentation_slide).to be_nil
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
      expect(Turbo::StreamsChannel).to have_received(:broadcast_refresh_to).exactly(3).times
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
      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_refresh_to)
    end
  end

  describe "PATCH /presentation/screen_chat" do
    def screen_chat(mode)
      patch "/scavenger_hunts/#{hunt.code}/presentation/screen_chat", params: {screen_chat: mode}, as: :json
    end

    it "refuses anyone without the remote" do
      cookies[:user_id] = "viewer"

      screen_chat("all")

      expect(response).to have_http_status(:forbidden)
      expect(hunt.reload.screen_chat).to eq("off")
      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_refresh_to)
    end

    it "starts off, then shows everything, only announcements, and nothing again, refreshing the screen each time" do
      expect(hunt.screen_chat).to eq("off")

      screen_chat("all")
      expect(response).to have_http_status(:no_content)
      expect(hunt.reload.screen_chat).to eq("all")

      screen_chat("announcements")
      expect(hunt.reload.screen_chat).to eq("announcements")

      screen_chat("off")
      expect(hunt.reload.screen_chat).to eq("off")
      expect(Turbo::StreamsChannel).to have_received(:broadcast_refresh_to).with("hunt_presenter_#{hunt.id}").exactly(3).times
    end

    it "rejects a mode it does not know" do
      screen_chat("everyone")

      expect(response).to have_http_status(:unprocessable_content)
      expect(hunt.reload.screen_chat).to eq("off")
      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_refresh_to)
    end
  end

  describe "GET /presenter/remote" do
    it "sends anyone without the remote to the presentation" do
      cookies[:user_id] = "viewer"

      get "/scavenger_hunts/#{hunt.code}/presenter/remote"

      expect(response).to redirect_to("/scavenger_hunts/#{hunt.code}/presenter")
    end

    it "shows the owner the current slide and the slide controls" do
      hunt.update!(presentation_slide: "submission:#{second.id}")

      get "/scavenger_hunts/#{hunt.code}/presenter/remote"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Photo 4 of 7", ERB::Util.html_escape(items.second.name), "Previous", "Next")
      expect(response.body).not_to include("Play on the big screen")
    end

    it "describes title cards and the finale" do
      get "/scavenger_hunts/#{hunt.code}/presenter/remote"

      expect(response.body).to include("Item 1 of 7", "Next up", ERB::Util.html_escape(items.first.name))

      hunt.update!(presentation_slide: "finale")
      get "/scavenger_hunts/#{hunt.code}/presenter/remote"

      expect(response.body).to include("Finale 7 of 7", "First place", ERB::Util.html_escape(team.name))
    end

    it "offers the big screen chat switches, reflecting the current mode" do
      Flipper.enable(:chat)
      get "/scavenger_hunts/#{hunt.code}/presenter/remote"

      switch_tag = ->(testid) { response.body[/<input[^>]*data-testid="#{testid}"[^>]*>/] }

      expect(response.body).to include("Big screen", "Show the chat", "Announcements only")
      expect(response.body).to include(%(data-remote-screen-chat-url-value="/scavenger_hunts/#{hunt.code}/presentation/screen_chat"))
      expect(switch_tag.call("screen-chat-switch")).not_to include("checked")
      expect(switch_tag.call("announcements-only-switch")).to include("disabled")

      hunt.update!(screen_chat: "announcements")
      get "/scavenger_hunts/#{hunt.code}/presenter/remote"

      expect(switch_tag.call("screen-chat-switch")).to include("checked")
      expect(switch_tag.call("announcements-only-switch")).to include("checked")
      expect(switch_tag.call("announcements-only-switch")).not_to include("disabled")
    end

    it "leaves the big screen chat switches out when the hunt has no chat" do
      Flipper.enable(:chat)
      hunt.update!(chat_enabled: false)

      get "/scavenger_hunts/#{hunt.code}/presenter/remote"

      expect(response.body).not_to include("Show the chat")
    end

    it "shows the video transport on a video slide" do
      video = create(:video_submission, item: items.first, team: create(:team, hunt:))
      hunt.update!(presentation_slide: "submission:#{video.id}")

      get "/scavenger_hunts/#{hunt.code}/presenter/remote"

      expect(response.body).to include("Video 3 of 8", "Play on the big screen", "Replay", "Sound on")

      hunt.update!(presentation_playback: "playing", presentation_muted: false)
      get "/scavenger_hunts/#{hunt.code}/presenter/remote"

      expect(response.body).to include("Pause", "Sound off")
      expect(response.body).not_to include("Play on the big screen")
    end
  end
end
