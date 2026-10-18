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
      hunt.update!(presentation_slide: "submission:#{second.id}")
      cookies[:user_id] = "owner"
      allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)

      get "/scavenger_hunts/#{hunt.code}/presenter?screen=big&slide=submission:#{first.id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Photo 3 of 4", %(id="submission_#{second.id}_photo"))
      expect(response.body).not_to include(%(id="submission_#{first.id}_photo"), "Browsing")
      expect(hunt.reload.presentation_slide).to eq("submission:#{second.id}")
      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_refresh_to)
    end

    it "lets a watcher browse another slide without leaving live for everyone else" do
      first = found(first_team, items.first)
      second = found(second_team, items.first)
      hunt.update!(presentation_slide: "submission:#{second.id}")

      get "/scavenger_hunts/#{hunt.code}/presenter?slide=submission:#{first.id}"

      expect(response.body).to include("Browsing", "Photo 2 of 4", %(id="submission_#{first.id}_photo"), "Back to live, now on 3 of 4")
      expect(response.body).to include(%(href="/scavenger_hunts/#{hunt.code}/presenter?slide=item%3A#{items.first.id}"))
      expect(response.body).to include(%(href="/scavenger_hunts/#{hunt.code}/presenter?slide=submission%3A#{second.id}"))
      expect(hunt.reload.presentation_slide).to eq("submission:#{second.id}")
    end

    it "treats an unknown slide as live" do
      found(first_team, items.first)

      get "/scavenger_hunts/#{hunt.code}/presenter?slide=finale-ish"

      expect(response.body).to include("Live", "Item 1 of 3")
      expect(response.body).not_to include("Browsing")
    end

    it "falls back to the first slide when the presented one is gone" do
      first = found(first_team, items.first)
      hunt.update!(presentation_slide: "submission:#{first.id + 100}")

      get "/scavenger_hunts/#{hunt.code}/presenter"

      expect(response.body).to include("Item 1 of 3", "Next up", ERB::Util.html_escape(items.first.name))
    end

    it "preloads the next photo and gives every print its own deterministic tilt" do
      first = found(first_team, items.first)
      second = found(second_team, items.first)
      hunt.update!(presentation_slide: "submission:#{first.id}")

      tilt_of = ->(body) { body[/id="submission_#{first.id}_print"[^>]*style="(--tilt: -?\d\.\ddeg)"[^>]*data-print/, 1] }

      get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"
      first_tilt = tilt_of.call(response.body)

      expect(response.body).to include(%(<link rel="preload" as="image" href="#{second.large_variant_url}"))
      expect(first_tilt).to be_present
      expect(response.body).to include(%(id="print_overlay"), %(data-controller="transition"))

      get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"
      expect(tilt_of.call(response.body)).to eq(first_tilt)

      hunt.update!(presentation_slide: "item:#{items.first.id}")
      get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

      expect(response.body).to include(%(<link rel="preload" as="image" href="#{first.large_variant_url}"), %(id="item_#{items.first.id}_card"))
    end

    it "seals the finale while the leaderboard is locked, on the big screen and on watchers' phones" do
      found(first_team, items.first)
      found(second_team, items.second)
      hunt.update!(lock_password: "hunter2", presentation_slide: "finale")

      expect(hunt.presentation.keys.last).to eq("finale")

      get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

      expect(response.body).to include("Finale 5 of 5", "First place", "And the winner is", "Sealed", "Final scores", "2 teams, 2 finds", "opens them from the remote")
      expect(response.body).to include(%(data-testid="finale"), %(data-testid="sealed-finale"), %(data-testid="confetti"), %(id="finale_sealed_card"))
      expect(response.body).not_to include(ERB::Util.html_escape(first_team.name), ERB::Util.html_escape(second_team.name), %(data-testid="winner-name"), %(data-testid="runners-up"), %(data-testid="most-loved"))
      expect(response.body).not_to match(/\d+ points?/)

      get "/scavenger_hunts/#{hunt.code}/presenter"

      expect(response.body).to include("Live", "Finale 5 of 5", "And the winner is", %(data-testid="sealed-finale"))
      expect(response.body).not_to include(ERB::Util.html_escape(first_team.name), ERB::Util.html_escape(second_team.name))
      expect(response.body).not_to match(/\d+ points?/)

      hunt.reveal_results!
      get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

      expect(response.body).to include(%(data-testid="winner-name"), %(id="finale_card"), ERB::Util.html_escape(first_team.name))
      expect(response.body).not_to include(%(data-testid="sealed-finale"))
    end

    it "shows the item title card with who found it" do
      found(first_team, items.first)
      found(second_team, items.first)
      hunt.update!(presentation_slide: "item:#{items.first.id}")

      get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

      expect(response.body).to include("Found by 2 of 2 teams, #{hunt.categories.first.points} #{"point".pluralize(hunt.categories.first.points)} each")
      expect(response.body).to include(ERB::Util.html_escape(first_team.name), ERB::Util.html_escape(second_team.name))
    end

    it "shows the finale with the winner, the runners-up and the most loved photo" do
      hunt.categories.first.update!(points: 5)
      winning = found(first_team, items.first)
      found(first_team, items.second)
      loved = found(second_team, items.first)
      loved.votes.create!(user_id: "a", value: "love")
      loved.votes.create!(user_id: "b", value: "love")
      winning.votes.create!(user_id: "a", value: "love")
      hunt.update!(presentation_slide: "finale")

      get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

      expect(response.body).to include("First place", ERB::Util.html_escape(first_team.name), "10 points", "5 points", "Most loved", "2 loves")
      expect(response.body).to include(%(data-testid="runners-up"), %(data-testid="confetti"))
      expect(response.body).to include(%(alt="#{ERB::Util.html_escape(second_team.name)} found #{ERB::Util.html_escape(items.first.name)}"))
    end

    context "with the chat column" do
      let(:first) { found(first_team, items.first) }
      let!(:older) { create(:message, hunt:, content: "Before the show", created_at: 2.minutes.ago) }
      let!(:hello) { create(:message, hunt:, sender_name: "Eric", team: first_team, content: "Hello from the floor") }
      let!(:pizza) { create(:message, hunt:, sender_name: "Host", organizer: true, announcement: true, content: "Pizza at 7") }
      let!(:gone) { create(:message, hunt:, content: "Oops", deleted_at: Time.current) }

      before do
        Flipper.enable(:chat)
        hunt.update!(presentation_slide: "submission:#{first.id}", screen_chat: "all")
      end

      it "shows recent messages beside the photo and subscribes to the chat" do
        get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

        expect(response.body).to include(%(data-testid="screen-chat"), "Party chat", "3 people, 1 team", "Chat from your phone. Messages show here for a minute.")
        expect(response.body).to include(%(<turbo-cable-stream-source id="chat_stream" data-turbo-permanent="true"))
        expect(response.body).to include(%(id="#{hunt.chat_list_id}"), "Hello from the floor", "Pizza at 7")
        expect(response.body).not_to include("Before the show", "Oops")
        expect(response.body).to include("Follow, vote and chat on your phone")
        expect(response.body).not_to include("Follow and vote on your phone")
      end

      it "shows only announcements in announcements mode" do
        hunt.update!(screen_chat: "announcements")

        get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

        expect(response.body).to include(%(data-screen-chat-mode-value="announcements"), "Pizza at 7")
        expect(response.body).not_to include("Hello from the floor")
      end

      it "keeps the most recent eight" do
        create_list(:message, 10, hunt:, content: "Filler")
        first_filler = hunt.messages.where(content: "Filler").order(:id).first

        get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

        expect(response.body.scan("Filler").size).to eq(8)
        expect(response.body).not_to include("Hello from the floor", %(id="message_#{first_filler.id}"))
      end

      it "stays beside the title card and the finale too" do
        hunt.update!(presentation_slide: "item:#{items.first.id}")
        get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"
        expect(response.body).to include(%(data-testid="title-card"), %(data-testid="screen-chat"), "Hello from the floor")
        expect(response.body).to include("Follow, vote and chat on your phone")

        hunt.update!(presentation_slide: "finale")
        get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"
        expect(response.body).to include(%(data-testid="finale"), %(data-testid="screen-chat"), "Hello from the floor")
        expect(response.body).to include("Follow, vote and chat on your phone")
      end

      it "stays off watchers' phones and screens with the chat off" do
        get "/scavenger_hunts/#{hunt.code}/presenter"
        expect(response.body).not_to include(%(data-testid="screen-chat"))
        expect(response.body).not_to include("Follow and vote on your phone")

        hunt.update!(screen_chat: "off")
        get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"
        expect(response.body).not_to include(%(data-testid="screen-chat"), %(id="chat_stream"))
        expect(response.body).to include("Follow and vote on your phone")

        hunt.update!(screen_chat: "all", chat_enabled: false)
        get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"
        expect(response.body).not_to include(%(data-testid="screen-chat"))
      end
    end

    it "opts out of the snapshot cache and morphs refreshes" do
      found(first_team, items.first)

      get "/scavenger_hunts/#{hunt.code}/presenter"

      expect(response.body).to include(%(<meta name="turbo-refresh-method" content="morph">), %(<meta name="turbo-cache-control" content="no-cache">))
      expect(response.body).to include(%(<turbo-cable-stream-source id="presenter_stream" data-turbo-permanent="true"))
    end

    it "renders the vote menu inline and offers the remote to anyone who does not hold it" do
      submission = found(first_team, items.first)
      hunt.update!(presentation_slide: "submission:#{submission.id}", remote_holder_id: "owner")
      cookies[:user_id] = "viewer"

      get "/scavenger_hunts/#{hunt.code}/presenter"

      expect(response.body).to include(%(id="submission_vote_viewer_#{submission.id}"), "Someone else has the remote", "Take the remote")
      expect(response.body).not_to include("turbo-frame")
    end

    it "offers the remote to the organizer until they take it, then tells them they have it" do
      found(first_team, items.first)
      cookies[:user_id] = "owner"

      get "/scavenger_hunts/#{hunt.code}/presenter"

      expect(response.body).to include("No one has the remote yet", "Take the remote")
      expect(response.body).not_to include("You have the remote")

      hunt.update!(remote_holder_id: "owner")
      get "/scavenger_hunts/#{hunt.code}/presenter"

      expect(response.body).to include("You have the remote", "Open the remote")
      expect(response.body).not_to include("Take the remote")
    end

    it "shows loves and flags instead of the vote menu on the big screen" do
      submission = found(first_team, items.first)
      submission.votes.create!(user_id: "a", value: "love")
      submission.votes.create!(user_id: "b", value: "deny")
      hunt.update!(presentation_slide: "submission:#{submission.id}", max_downvotes_to_lose_points: 3)

      get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

      expect(response.body).to include(%(data-playback-follow-value="true"), %(id="submission_#{submission.id}_reactions"), "1 love", "1 of 3 flags", %(id="reactions"))
      expect(response.body).not_to include(%(id="submission_vote_), "submission_#{submission.id}_video", "Doesn't count")
    end

    it "shows the threshold as the flag count on the big screen once flags go past it" do
      submission = found(first_team, items.first)
      hunt.update!(presentation_slide: "submission:#{submission.id}", max_downvotes_to_lose_points: 2)
      %w[a b c].each { |user_id| submission.votes.create!(user_id:, value: "deny") }
      submission.calculate_denied_points

      get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

      expect(response.body).to include("2 of 2 flags", "Doesn't count")
      expect(response.body).not_to include("3 of 2 flags")
    end

    it "plays the converted video with its poster" do
      video = create(:video_submission, item: items.first, team: first_team).reload
      hunt.update!(presentation_slide: "submission:#{video.id}")

      get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

      expect(response.body).to include(%(src="#{rails_blob_path(video.playback)}"), %(poster="#{video.poster_url}"))
      expect(response.body).not_to include(rails_blob_path(video.photo))
    end

    it "plays the original while the converted video is still being made", :test_queue_adapter do
      video = create(:video_submission, item: items.first, team: first_team)
      hunt.update!(presentation_slide: "submission:#{video.id}")

      get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

      expect(response.body).to include(%(src="#{rails_blob_path(video.photo)}"))
      expect(response.body).not_to include("poster=")
    end

    it "keeps a hidden sound button on a big-screen video slide for browsers that block audio" do
      video = create(:video_submission, item: items.first, team: first_team)
      hunt.update!(presentation_slide: "submission:#{video.id}")

      get "/scavenger_hunts/#{hunt.code}/presenter?screen=big"

      expect(response.body).to include(%(id="submission_#{video.id}_sound_button"), "Tap to enable sound")
      expect(response.body).to match(/id="submission_#{video.id}_sound_button"[^>]*\shidden\s[^>]*data-turbo-permanent/)
      expect(response.body).not_to include(%(id="submission_#{video.id}_play_button"))
    end

    it "renders with the same number of queries however many photos there are" do
      hunt.update!(presentation_slide: "submission:#{found(first_team, items.first).id}")
      found(first_team, items.second)
      path = "/scavenger_hunts/#{hunt.code}/presenter"
      get path
      few = queries_for(path)

      found(second_team, items.first)
      found(second_team, items.second)
      found(second_team, items.third)
      many = queries_for(path)

      expect(response).to have_http_status(:ok)
      expect(many).to eq(few)
    end
  end

  describe "POST /presentation/claim" do
    before { found(first_team, items.first) }

    it "hands the remote to the viewer, tells every screen and sends them to it" do
      cookies[:user_id] = "viewer"
      allow(Turbo::StreamsChannel).to receive(:broadcast_refresh_to)

      post "/scavenger_hunts/#{hunt.code}/presentation/claim"

      expect(response).to redirect_to("/scavenger_hunts/#{hunt.code}/presenter/remote")
      expect(hunt.reload).to have_attributes(remote_holder_id: "viewer", owner_id: "owner")
      expect(Turbo::StreamsChannel).to have_received(:broadcast_refresh_to).with("hunt_presenter_#{hunt.id}").once
    end

    context "when the results are locked with a password" do
      before { hunt.update!(lock_password: "hunter2") }

      it "refuses without the password" do
        cookies[:user_id] = "viewer"

        post "/scavenger_hunts/#{hunt.code}/presentation/claim", params: {password: "nope"}

        expect(response).to redirect_to("/scavenger_hunts/#{hunt.code}/presenter")
        expect(flash[:warning]).to eq("Incorrect password")
        expect(hunt.reload).to have_attributes(remote_holder_id: nil, owner_id: "owner")
      end

      it "hands over the remote with the password" do
        cookies[:user_id] = "viewer"

        post "/scavenger_hunts/#{hunt.code}/presentation/claim", params: {password: "hunter2"}

        expect(response).to redirect_to("/scavenger_hunts/#{hunt.code}/presenter/remote")
        expect(hunt.reload).to have_attributes(remote_holder_id: "viewer", owner_id: "owner")
      end

      it "asks for the password on the presenter page" do
        cookies[:user_id] = "viewer"

        get "/scavenger_hunts/#{hunt.code}/presenter"

        expect(response.body).to include("Take the remote", %(type="password"))
      end
    end
  end
end
