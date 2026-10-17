# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Messages" do
  include ActiveSupport::Testing::TimeHelpers

  let(:hunt) { create(:hunt, owner_id: "organizer") }
  let(:team) { create(:team, hunt:, name: "Blue Bandits") }
  let(:turbo) { {"Accept" => "text/vnd.turbo-stream.html"} }

  before do
    Flipper.enable(:chat)
    cookies[:user_id] = "viewer"
  end

  def set_name(name)
    patch "/scavenger_hunts/#{hunt.code}/chat_name", params: {name:}, headers: turbo
  end

  def send_message(content, announcement: nil)
    post "/scavenger_hunts/#{hunt.code}/messages", params: {message: {content:, announcement:}.compact}, headers: turbo
  end

  describe "POST /messages" do
    it "asks for a name before the first message" do
      send_message("Hello")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Pick a name")
      expect(hunt.messages.count).to eq(0)
    end

    it "appends the sender's own message as a turbo stream with their name and team" do
      get "/scavenger_hunts/#{hunt.code}/teams/#{team.id}"
      set_name("Eric")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sending as <strong", "Eric", "Blue Bandits")

      send_message("Hello everyone")

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include(%(action="append" target="hunt_chat_#{hunt.id}"), "Hello everyone", "data-own")
      message = hunt.messages.last
      expect(message).to have_attributes(sender_name: "Eric", team:, user_id: "viewer", organizer: false)
    end

    it "signs the organizer's ordinary messages as the organizer" do
      cookies[:user_id] = "organizer"
      set_name("Host")

      send_message("Welcome!")

      expect(hunt.messages.last).to have_attributes(organizer: true, announcement: false)
      expect(response.body).to include("Organizer", "Welcome!")
      expect(response.body).not_to include("data-announcement", "Announcement")
    end

    it "lets the organizer mark a message as an announcement" do
      cookies[:user_id] = "organizer"
      set_name("Host")

      send_message("Pizza at 7", announcement: "1")

      expect(hunt.messages.last).to have_attributes(organizer: true, announcement: true)
      expect(response.body).to include("data-announcement", "Announcement")
    end

    it "rejects an announcement from anyone but the organizer" do
      set_name("Eric")

      send_message("Free pizza for everyone", announcement: "1")

      expect(response).to have_http_status(:forbidden)
      expect(response.body).to include("Only the organizer can send announcements")
      expect(hunt.messages.count).to eq(0)
    end

    it "rejects a message over 280 characters" do
      set_name("Eric")

      send_message("a" * 281)

      expect(response).to have_http_status(:unprocessable_content)
      expect(hunt.messages.count).to eq(0)
    end

    it "allows one message a second per viewer" do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      set_name("Eric")

      send_message("One")
      send_message("Two")
      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("One message a second")

      cookies[:user_id] = "someone else"
      set_name("Dana")
      send_message("Three")
      expect(response).to have_http_status(:ok)

      travel 2.seconds do
        cookies[:user_id] = "viewer"
        set_name("Eric")
        send_message("Four")
        expect(response).to have_http_status(:ok)
      end

      expect(hunt.messages.order(:id).pluck(:content)).to eq(%w[One Three Four])
    end

    it "broadcasts the message and, for an announcement, the pin to the hunt's chat stream" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
      cookies[:user_id] = "organizer"
      set_name("Host")

      send_message("Welcome!")
      expect(Turbo::StreamsChannel).not_to have_received(:broadcast_replace_to)

      send_message("Pizza at 7", announcement: "1")

      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to)
        .with(hunt.chat_stream, hash_including(target: "hunt_chat_#{hunt.id}", partial: "messages/message")).twice
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
        .with(hunt.chat_stream, hash_including(target: "chat_pinned_#{hunt.id}", partial: "messages/pinned")).once
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
        .with(hunt.chat_stream, hash_including(target: "organizer_card_#{hunt.id}", partial: "messages/organizer_card")).once
    end

    it "is forbidden when the hunt turned chat off" do
      hunt.update!(chat_enabled: false)
      set_name("Eric")

      send_message("Hello")

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /chat_name" do
    it "rejects a blank name" do
      set_name("   ")

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Enter a name")
    end

    it "squishes and truncates the name" do
      set_name("  Eric   #{"x" * 60}")

      expect(response).to have_http_status(:ok)
      send_message("Hi")
      expect(hunt.messages.last.sender_name.length).to eq(40)
    end
  end

  describe "DELETE /messages/:id" do
    let!(:message) { create(:message, hunt:, content: "Oops") }

    it "is forbidden for anyone but the organizer" do
      delete "/scavenger_hunts/#{hunt.code}/messages/#{message.id}", headers: turbo

      expect(response).to have_http_status(:forbidden)
      expect(message.reload).not_to be_removed
    end

    it "soft deletes and replaces the bubble for the organizer" do
      allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
      cookies[:user_id] = "organizer"

      delete "/scavenger_hunts/#{hunt.code}/messages/#{message.id}", headers: turbo

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(action="replace" target="message_#{message.id}"), "Message removed")
      expect(response.body).not_to include("Oops")
      expect(message.reload).to be_removed
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to)
        .with(hunt.chat_stream, hash_including(target: message, partial: "messages/message")).once
    end
  end

  describe "GET /messages" do
    before { create_list(:message, 120, hunt:) }

    it "renders the whole sheet with the latest 50 and a frame that loads the earlier ones" do
      create(:message, hunt:, organizer: true, announcement: true, content: "Pinned for later")

      get "/scavenger_hunts/#{hunt.code}/messages", headers: {"Turbo-Frame" => "chat_box_#{hunt.id}"}

      expect(response).to have_http_status(:ok)
      expect(response.body).to match(/<turbo-frame[^>]*id="chat_box_#{hunt.id}"/)
      expect(response.body).to include("Everyone in the hunt", 'data-testid="chat-pinned"', "Pinned for later", "What should we call you?")
      ids = hunt.messages.order(:id).pluck(:id)
      expect(response.body.scan('data-testid="chat-message"').size).to eq(50)
      expect(response.body).to include(%(id="message_#{ids.last}"))
      expect(response.body).not_to include(%(id="message_#{ids[-51]}"))
      expect(response.body).to match(/<turbo-frame[^>]*id="chat_earlier_#{ids[-50]}"/)
      expect(response.body).to include("before=#{ids[-50]}", "Show earlier")

      get "/scavenger_hunts/#{hunt.code}/messages?before=#{ids[-50]}", headers: {"Turbo-Frame" => "chat_earlier_#{ids[-50]}"}

      expect(response.body).to match(/<turbo-frame[^>]*id="chat_earlier_#{ids[-50]}"/)
      expect(response.body.scan('data-testid="chat-message"').size).to eq(50)
      expect(response.body).to include(%(id="message_#{ids[-51]}"), %(id="message_#{ids[-100]}"))
      expect(response.body).to match(/<turbo-frame[^>]*id="chat_earlier_#{ids[-100]}"/)
      expect(response.body).to include("before=#{ids[-100]}")

      get "/scavenger_hunts/#{hunt.code}/messages?before=#{ids[-100]}"

      expect(response.body.scan('data-testid="chat-message"').size).to eq(21)
      expect(response.body).not_to include("Show earlier")
    end
  end

  describe "GET /teams/:id" do
    it "shows the chat with the latest announcement pinned and on the 'From the organizer' card" do
      create(:message, hunt:, organizer: true, announcement: true, content: "Old news")
      create(:message, hunt:, organizer: true, announcement: true, content: "Pizza at 7")
      create(:message, hunt:, organizer: true, content: "Just chatting")

      get "/scavenger_hunts/#{hunt.code}/teams/#{team.id}"

      expect(response.body).to include('data-testid="chat-pill"')
      expect(response.body).to match(%r{<turbo-frame[^>]*id="chat_box_#{hunt.id}"[^>]*src="/scavenger_hunts/#{hunt.code}/messages"})
      expect(response.body.scan("Pizza at 7").size).to eq(1)
      expect(response.body).not_to include("Old news", "Just chatting", "What should we call you?")

      get "/scavenger_hunts/#{hunt.code}/messages", headers: {"Turbo-Frame" => "chat_box_#{hunt.id}"}

      expect(response.body).to include("What should we call you?")
      expect(response.body.scan("Pizza at 7").size).to eq(2)
      expect(response.body.scan("Old news").size).to eq(1)
      expect(response.body.scan("Just chatting").size).to eq(1)
    end

    it "shows the announcement megaphone to the organizer only" do
      set_name("Eric")
      get "/scavenger_hunts/#{hunt.code}/teams/#{team.id}"
      expect(response.body).not_to match(/<turbo-frame[^>]*data-chat-organizer/)
      get "/scavenger_hunts/#{hunt.code}/messages", headers: {"Turbo-Frame" => "chat_box_#{hunt.id}"}
      expect(response.body).not_to include('data-testid="chat-announcement-toggle"')

      cookies[:user_id] = "organizer"
      get "/scavenger_hunts/#{hunt.code}/teams/#{team.id}"
      expect(response.body).to match(/<turbo-frame[^>]*data-chat-organizer/)
      get "/scavenger_hunts/#{hunt.code}/messages", headers: {"Turbo-Frame" => "chat_box_#{hunt.id}"}
      expect(response.body).to include('data-testid="chat-announcement-toggle"', 'aria-pressed="false"')
    end

    it "hides the chat when the hunt turned it off or the kill switch is down" do
      hunt.update!(chat_enabled: false)
      get "/scavenger_hunts/#{hunt.code}/teams/#{team.id}"
      expect(response.body).not_to include('data-testid="chat-pill"')

      hunt.update!(chat_enabled: true)
      Flipper.disable(:chat)
      get "/scavenger_hunts/#{hunt.code}/teams/#{team.id}"
      expect(response.body).not_to include('data-testid="chat-pill"')
    end
  end
end
