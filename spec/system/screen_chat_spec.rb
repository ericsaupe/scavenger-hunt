# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Big screen chat" do
  let(:hunt) { create(:hunt) }
  let!(:team) { create(:team, hunt:, name: "Blue Bandits") }

  before do
    Flipper.enable(:chat)
    @photo = create(:photo_submission, item: hunt.items.first, team:)
    hunt.update!(presentation_slide: "submission:#{@photo.id}")
  end

  def big_screen_path
    "/scavenger_hunts/#{hunt.code}/presenter?screen=big"
  end

  def viewer_id
    page.driver.browser.manage.cookie_named("user_id")[:value]
  end

  def open_chat
    find("[data-testid='chat-pill']").click
    expect(page).to have_css("[data-testid='chat-sheet'].modal-open")
  end

  def set_name(name)
    fill_in "What should we call you?", with: name
    click_on "Save"
    expect(page).to have_text("Sending as #{name}")
  end

  def send_message(text)
    fill_in "message_content", with: text
    click_on "Send"
    expect(page).to have_css("[data-testid='chat-message'][data-own]", text: text)
  end

  def style_of(selector, property)
    page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).#{property}")
  end

  def width_of(selector)
    page.evaluate_script("document.querySelector(#{selector.to_json}).getBoundingClientRect().width")
  end

  def eventually
    10.times do
      return if yield
      sleep 0.2
    end
    expect(yield).to be(true)
  end

  it "lets the host put the party chat beside the photo, in full or announcements only, and take it away again" do
    using_session(:big_screen) do
      visit big_screen_path
      expect(page).to have_css("[data-testid='photo-slide']")
      expect(page).to have_css("[data-testid='join-line']", text: "Follow and vote on your phone")
      expect(page).not_to have_css("[data-testid='screen-chat']")
    end

    visit "/scavenger_hunts/#{hunt.code}/presenter"
    hunt.update!(remote_holder_id: viewer_id)
    visit "/scavenger_hunts/#{hunt.code}/presenter/remote"
    expect(page).to have_css("[data-testid='announcements-only-switch']:disabled")
    find("[data-testid='screen-chat-switch']").click
    expect(page).to have_css("[data-testid='screen-chat-switch']:checked")
    expect(page).to have_css("[data-testid='announcements-only-switch']:enabled")
    eventually { hunt.reload.screen_chat == "all" }

    using_session(:big_screen) do
      expect(page).to have_css("[data-testid='screen-chat']")
      expect(page).to have_css("[data-testid='screen-chat-summary']", text: "0 people, 1 team")
      expect(page).to have_text("Chat from your phone. Messages show here for a minute.")
      expect(page).to have_css("[data-testid='join-line']", text: "Follow, vote and chat on your phone")
      expect(page).to have_css("img#submission_#{@photo.id}_photo")
      expect(width_of("[data-testid='screen-chat']")).to eq(460)
      expect(style_of("[data-testid='screen-chat']", "backgroundColor")).to eq("rgb(11, 13, 16)")
      print_right = page.evaluate_script("document.querySelector('[data-print]').getBoundingClientRect().right")
      column_left = page.evaluate_script("document.querySelector('[data-testid=screen-chat]').getBoundingClientRect().left")
      expect(print_right).to be <= column_left
    end

    using_session(:watcher) do
      visit "/scavenger_hunts/#{hunt.code}/teams/#{team.id}"
      visit "/scavenger_hunts/#{hunt.code}/presenter"
      open_chat
      set_name("Eric")
      send_message("Found the fountain!")
    end

    using_session(:big_screen) do
      within("[data-testid='screen-chat']") do
        expect(page).to have_css("[data-testid='chat-message']:not([data-announcement])", text: "Found the fountain!")
        within("[data-testid='chat-message']", text: "Found the fountain!") do
          expect(page).to have_text("Eric")
          expect(page).to have_text("Blue Bandits")
          expect(page).to have_css("[data-testid='sender-avatar']")
        end
      end
      expect(width_of("[data-testid='screen-chat'] [data-testid='sender-avatar']")).to eq(44)
      expect(style_of("[data-testid='screen-chat'] .message-meta", "fontSize")).to eq("17px")
      expect(style_of("[data-testid='screen-chat'] .message-bubble", "fontSize")).to eq("22px")
    end

    visit "/scavenger_hunts/#{hunt.code}/presenter"
    open_chat
    set_name("Host")
    find("[data-testid='chat-announcement-toggle']").click
    send_message("Pizza at 7 by the gazebo")

    using_session(:big_screen) do
      within("[data-testid='screen-chat']") do
        expect(page).to have_css("[data-testid='chat-message'][data-announcement]", text: "Pizza at 7 by the gazebo")
        expect(page).to have_css("[data-testid='chat-message']", count: 2)
        expect(page).to have_css("[data-testid='chat-message'][data-announcement] [data-testid='announcement-badge']")
        expect(page).to have_css("[data-testid='chat-message'][data-announcement] [data-testid='sender-avatar']", visible: :hidden)
      end
      expect(style_of("[data-testid='screen-chat'] [data-announcement]", "borderTopColor")).to eq("rgb(255, 183, 3)")
      expect(style_of("[data-testid='screen-chat'] [data-announcement]", "backgroundColor")).to eq("rgb(27, 31, 36)")
      expect(width_of("[data-testid='screen-chat'] [data-testid='announcement-badge']")).to eq(44)
      eventually { style_of("[data-testid='screen-chat'] [data-message-id]", "opacity") == "0.45" }
      eventually { style_of("[data-testid='screen-chat'] [data-announcement]", "opacity") == "1" }
    end

    visit "/scavenger_hunts/#{hunt.code}/presenter/remote"
    find("[data-testid='announcements-only-switch']").click
    expect(page).to have_css("[data-testid='announcements-only-switch']:checked")
    eventually { hunt.reload.screen_chat == "announcements" }

    using_session(:big_screen) do
      within("[data-testid='screen-chat']") do
        expect(page).not_to have_text("Found the fountain!")
        expect(page).to have_text("Pizza at 7 by the gazebo")
        expect(page).to have_css("[data-testid='screen-chat-summary']", text: "2 people, 1 team")
      end
    end

    using_session(:watcher) { send_message("Any left?") }
    visit "/scavenger_hunts/#{hunt.code}/presenter"
    open_chat
    find("[data-testid='chat-announcement-toggle']").click
    send_message("Plenty")

    using_session(:big_screen) do
      within("[data-testid='screen-chat']") do
        expect(page).to have_text("Plenty")
        expect(page).not_to have_text("Any left?")
        expect(page).to have_css("[data-testid='chat-message']", count: 2)
      end
    end

    using_session(:big_screen) do
      find("[data-testid='screen-chat'] [data-testid='chat-message']", text: "Plenty").execute_script("this.dataset.shownSince = 'photo'")
    end

    hunt.reload.present!("item:#{hunt.items.first.id}")
    using_session(:big_screen) do
      expect(page).to have_css("[data-testid='title-card']")
      expect(page).to have_css("[data-testid='join-line']", text: "Follow, vote and chat on your phone")
      within("[data-testid='screen-chat']") do
        expect(page).to have_css("[data-shown-since='photo']", text: "Plenty")
        expect(page).not_to have_text("Any left?")
      end
    end

    hunt.reload.present!("finale")
    using_session(:big_screen) do
      expect(page).to have_css("[data-testid='finale']")
      expect(page).to have_css("[data-testid='join-line']", text: "Follow, vote and chat on your phone")
      within("[data-testid='screen-chat']") do
        expect(page).to have_css("[data-shown-since='photo']", text: "Plenty")
      end
    end

    hunt.reload.present!("submission:#{@photo.id}")
    using_session(:big_screen) do
      expect(page).to have_css("[data-testid='photo-slide']")
      within("[data-testid='screen-chat']") do
        expect(page).to have_css("[data-shown-since='photo']", text: "Plenty")
        expect(page).not_to have_text("Any left?")
      end
    end

    visit "/scavenger_hunts/#{hunt.code}/presenter/remote"
    find("[data-testid='screen-chat-switch']").click
    expect(page).to have_css("[data-testid='announcements-only-switch']:disabled")
    eventually { hunt.reload.screen_chat == "off" }

    using_session(:big_screen) do
      expect(page).not_to have_css("[data-testid='screen-chat']")
      expect(page).not_to have_css("#chat_stream", visible: :all)
      expect(page).to have_css("[data-testid='join-line']", text: "Follow and vote on your phone")
      expect(page).to have_css("img#submission_#{@photo.id}_photo")
    end
  end

  it "keeps eight messages, drops each after its minute and loses removed ones at once" do
    hunt.update!(screen_chat: "all", remote_holder_id: "host")
    create_list(:message, 9, hunt:, content: "Warm-up")
    earliest = hunt.messages.order(:id).first

    visit big_screen_path
    expect(page).to have_css("[data-testid='screen-chat'] [data-testid='chat-message']", count: 8)
    expect(page).not_to have_css("##{ActionView::RecordIdentifier.dom_id(earliest)}")

    page.execute_script("document.querySelector('[data-testid=screen-chat]').dataset.screenChatTtlValue = '1500'")
    create(:message, hunt:, content: "Blink and you miss it")
    expect(page).to have_css("[data-testid='chat-message']", text: "Blink and you miss it")
    expect(page).to have_css("[data-testid='screen-chat'] [data-testid='chat-message']", count: 8)
    expect(page).to have_no_css("[data-testid='chat-message']", text: "Blink and you miss it", wait: 5)
    expect(page).to have_css("[data-testid='screen-chat'] [data-testid='chat-message']", count: 7)

    page.execute_script("document.querySelector('[data-testid=screen-chat]').dataset.screenChatTtlValue = '60000'")
    regretted = create(:message, hunt:, content: "Take that back")
    expect(page).to have_css("[data-testid='chat-message']", text: "Take that back")
    regretted.remove!
    expect(page).to have_no_css("[data-testid='chat-message']", text: "Take that back")
    expect(page).not_to have_text("Message removed")
  end

  it "brings back eligible recent messages when the mode changes" do
    hunt.update!(screen_chat: "all", remote_holder_id: "host")
    create(:message, hunt:, sender_name: "Host", organizer: true, announcement: true, content: "Pizza at 7")
    create_list(:message, 8, hunt:, content: "Warm-up")

    visit big_screen_path
    expect(page).to have_css("[data-testid='screen-chat'] [data-testid='chat-message']", count: 8)
    expect(page).not_to have_text("Pizza at 7")

    hunt.reload.screen_chat!("announcements")
    within("[data-testid='screen-chat']") do
      expect(page).to have_css("[data-testid='chat-message'][data-announcement]", text: "Pizza at 7")
      expect(page).to have_css("[data-testid='chat-message']", count: 1)
    end

    hunt.reload.screen_chat!("all")
    within("[data-testid='screen-chat']") do
      expect(page).to have_css("[data-testid='chat-message']", text: "Warm-up", count: 8)
      expect(page).not_to have_text("Pizza at 7")
    end
  end
end
