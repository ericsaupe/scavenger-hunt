# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Presenter" do
  let(:hunt) { create(:hunt, owner_id: "owner") }
  let(:items) { hunt.items.order(:id).to_a }
  let(:first_team) { create(:team, hunt:) }
  let(:second_team) { create(:team, hunt:) }

  def queries_for(path)
    count = 0
    counter = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get path }
    count
  end

  def found(team, item)
    submission = team.submissions.find_by(item:)
    submission.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
    submission
  end

  describe "GET /presenter" do
    it "redirects when nothing has been found yet" do
      get "/scavenger_hunts/#{hunt.code}/presenter"

      expect(response).to redirect_to("/scavenger_hunts/#{hunt.code}")
    end

    it "shows the current slide with its position but changes nothing, even for the owner" do
      first = found(first_team, items.first)
      second = found(second_team, items.first)
      hunt.update!(presentation_submission: second)
      cookies[:user_id] = "owner"
      allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_later_to)

      get "/scavenger_hunts/#{hunt.code}/presenter?submission_id=#{first.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Photo 2 of 2", %(id="submission_#{second.id}_photo"))
      expect(response.body).not_to include(%(id="submission_#{first.id}_photo"))
      expect(hunt.reload.presentation_submission).to eq(second)
      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_refresh_later_to)
    end

    it "falls back to the first slide when the presented one is gone" do
      first = found(first_team, items.first)
      hunt.update!(presentation_submission_id: first.id + 100)

      get "/scavenger_hunts/#{hunt.code}/presenter"

      expect(response.body).to include("Photo 1 of 1", %(id="submission_#{first.id}_photo"))
    end

    it "opts out of the snapshot cache and morphs refreshes" do
      found(first_team, items.first)

      get "/scavenger_hunts/#{hunt.code}/presenter"

      expect(response.body).to include(%(<meta name="turbo-refresh-method" content="morph">), %(<meta name="turbo-cache-control" content="no-cache">))
      expect(response.body).to include(%(<turbo-cable-stream-source id="presenter_stream" data-turbo-permanent="true"))
    end

    it "renders the vote menu inline and offers the remote to anyone who does not hold it" do
      submission = found(first_team, items.first)
      cookies[:user_id] = "viewer"

      get "/scavenger_hunts/#{hunt.code}/presenter"

      expect(response.body).to include(%(id="submission_vote_viewer_#{submission.id}"), "Someone else has the remote", "Take the remote")
      expect(response.body).not_to include("turbo-frame")
    end

    it "tells the owner they have the remote" do
      found(first_team, items.first)
      cookies[:user_id] = "owner"

      get "/scavenger_hunts/#{hunt.code}/presenter"

      expect(response.body).to include("You have the remote", "Open the remote")
      expect(response.body).not_to include("Take the remote")
    end

    it "hides the vote menu on the big screen" do
      submission = found(first_team, items.first)

      get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

      expect(response.body).to include(%(data-playback-follow-value="true"))
      expect(response.body).not_to include(%(id="submission_vote_), "submission_#{submission.id}_video")
    end

    it "renders with the same number of queries however many photos there are" do
      found(first_team, items.first)
      path = "/scavenger_hunts/#{hunt.code}/presenter"
      get path
      few = queries_for(path)

      found(second_team, items.first)
      found(first_team, items.second)
      found(second_team, items.third)
      many = queries_for(path)

      expect(response).to have_http_status(:ok)
      expect(many).to eq(few)
    end
  end

  describe "POST /presentation/claim" do
    before { found(first_team, items.first) }

    it "hands the remote to the viewer and sends them to it" do
      cookies[:user_id] = "viewer"

      post "/scavenger_hunts/#{hunt.code}/presentation/claim"

      expect(response).to redirect_to("/scavenger_hunts/#{hunt.code}/presenter/remote")
      expect(hunt.reload.owner_id).to eq("viewer")
    end

    context "when the results are locked with a password" do
      before { hunt.update!(lock_password: "hunter2") }

      it "refuses without the password" do
        cookies[:user_id] = "viewer"

        post "/scavenger_hunts/#{hunt.code}/presentation/claim", params: {password: "nope"}

        expect(response).to redirect_to("/scavenger_hunts/#{hunt.code}/presenter")
        expect(flash[:warning]).to eq("Incorrect password")
        expect(hunt.reload.owner_id).to eq("owner")
      end

      it "hands over the remote with the password" do
        cookies[:user_id] = "viewer"

        post "/scavenger_hunts/#{hunt.code}/presentation/claim", params: {password: "hunter2"}

        expect(response).to redirect_to("/scavenger_hunts/#{hunt.code}/presenter/remote")
        expect(hunt.reload.owner_id).to eq("viewer")
      end

      it "asks for the password on the presenter page" do
        cookies[:user_id] = "viewer"

        get "/scavenger_hunts/#{hunt.code}/presenter"

        expect(response.body).to include("Take the remote", %(type="password"))
      end
    end
  end
end
