# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Party chat" do
  let(:hunt) { create(:hunt) }
  let!(:team) { create(:team, hunt:, name: "Blue Bandits") }
  let!(:other_team) { create(:team, hunt:, name: "Red Rockets") }

  before { Flipper.enable(:chat) }

  def checklist_path(team)
    "/scavenger_hunts/#{hunt.code}/teams/#{team.id}"
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

  def viewer_id
    page.driver.browser.manage.cookie_named("user_id")[:value]
  end

  it "sends a named, team-coloured message that another viewer sees with an unread badge" do
    visit checklist_path(team)
    using_session(:other) do
      visit checklist_path(other_team)
      expect(page).to have_css("[data-testid='chat-pill']")
      expect(page).to have_css("[data-testid='chat-unread']", visible: :hidden)
    end

    open_chat
    expect(page).to have_text("Everyone in the hunt, 2 teams")
    expect(page).to have_text("No messages yet")
    set_name("Eric")
    expect(page).to have_text("Sending as Eric, Blue Bandits")
    send_message("Found the fountain!")
    expect(page).to have_css("[data-testid='chat-counter']", text: "0/280")
    within("[data-testid='chat-message']") do
      expect(page).to have_text("Blue Bandits")
      expect(page).to have_text("Eric")
      expect(page).to have_css("time", text: /\A\d{1,2}:\d{2}\z/)
    end
    expect(page).to have_css("[data-testid='chat-message']", count: 1)

    using_session(:other) do
      expect(page).to have_css("[data-testid='chat-unread']", text: "1")
      open_chat
      expect(page).to have_css("[data-testid='chat-message']:not([data-own])", text: "Found the fountain!")
      expect(page).to have_css("[data-testid='chat-unread']", visible: :hidden)
      expect(page).to have_css("[data-testid='sender-avatar'][src='#{hunt.messages.sole.avatar_url}']")
      set_name("Dana")
      send_message("Nice one")
    end

    expect(page).to have_css("[data-testid='chat-message']:not([data-own])", text: "Nice one")
    expect(page).to have_css("[data-testid='chat-message']", count: 2)

    click_on "Change name"
    set_name("Eric S")
    send_message("Still me")
    expect(hunt.messages.order(:id).pluck(:sender_name)).to eq(["Eric", "Dana", "Eric S"])

    find("[data-testid='chat-sheet'] button[aria-label='Close chat']", match: :first).click
    expect(page).not_to have_css("[data-testid='chat-sheet'].modal-open")
  end

  it "pins the organizer's announcement, shows it on the checklist and lets them remove messages" do
    visit checklist_path(team)
    hunt.update!(owner_id: viewer_id)
    create(:message, hunt:, content: "Who took the cones?", sender_name: "Dana", team: other_team)
    visit checklist_path(team)
    expect(page).not_to have_css("[data-testid='organizer-card']", text: /from the organizer/i)

    open_chat
    set_name("Host")
    send_message("Hi all, Host here")
    expect(page).to have_css("[data-testid='chat-message']:not([data-announcement])", text: "Hi all, Host here")
    expect(page).not_to have_css("[data-testid='chat-pinned']", text: "Hi all")

    find("[data-testid='chat-announcement-toggle']").click
    expect(page).to have_css("[data-testid='chat-announcement-toggle'][aria-pressed='true']")
    send_message("Pizza at 7 by the gazebo")
    expect(page).to have_css("[data-testid='chat-pinned']", text: "Pizza at 7 by the gazebo")
    expect(page).to have_css("[data-testid='chat-message'][data-announcement]", text: "Announcement")
    expect(page).to have_css("[data-testid='chat-message'][data-announcement] .message-avatar [data-testid='sender-avatar']", visible: :all)
    expect(page).to have_css("[data-testid='chat-message'][data-announcement] .message-avatar [data-testid='announcement-badge']", visible: :all)
    expect(page).to have_css("[data-testid='chat-announcement-toggle'][aria-pressed='false']")

    using_session(:other) do
      visit checklist_path(other_team)
      expect(page).to have_css("[data-testid='organizer-card']", text: /from the organizer/i)
      expect(page).to have_css("[data-testid='organizer-card']", text: "Pizza at 7 by the gazebo")
      expect(page).not_to have_css("[data-testid='organizer-card']", text: "Hi all")
      expect(page).to have_css("[data-testid='chat-unread']", text: "3")
      expect(page).not_to have_css("[data-testid='chat-announcement-toggle']")
    end

    accept_confirm do
      within("[data-testid='chat-message']", text: "Who took the cones?") { find("[data-testid='chat-remove']").click }
    end
    expect(page).to have_css("[data-testid='chat-message'][data-removed]", text: "Message removed")
    expect(page).not_to have_text("Who took the cones?")

    using_session(:other) do
      open_chat
      expect(page).to have_css("[data-testid='chat-message'][data-removed]", text: "Message removed")
      expect(page).not_to have_css("[data-testid='chat-remove']", visible: :visible)
    end
  end

  it "loads earlier messages fifty at a time" do
    create_list(:message, 60, hunt:)
    oldest = hunt.messages.order(:id).first
    visit checklist_path(team)
    open_chat
    expect(page).to have_css("[data-testid='chat-message']", count: 50)
    expect(page).not_to have_css("##{ActionView::RecordIdentifier.dom_id(oldest)}")

    click_on "Show earlier"
    expect(page).to have_css("[data-testid='chat-message']", count: 60)
    expect(page).to have_css("##{ActionView::RecordIdentifier.dom_id(oldest)}")
    expect(page).not_to have_link("Show earlier")
  end

  it "re-fetches the sheet when the tab becomes visible again, keeping the draft and announcement mode" do
    visit checklist_path(team)
    hunt.update!(owner_id: viewer_id)
    visit checklist_path(team)
    open_chat
    set_name("Host")
    Message.suppressing_turbo_broadcasts { create(:message, hunt:, content: "Missed while away") }
    expect(page).not_to have_text("Missed while away")
    find("[data-testid='chat-announcement-toggle']").click
    fill_in "message_content", with: "Half a thought"

    page.execute_script(<<~JS)
      document.body.dataset.stale = "1"
      Object.defineProperty(document, "visibilityState", { value: "visible", configurable: true })
      document.dispatchEvent(new Event("visibilitychange"))
    JS
    expect(page).to have_no_css("body[data-stale]")
    expect(page).to have_text("Missed while away")
    expect(page).to have_field("message_content", with: "Half a thought")
    expect(page).to have_css("[data-testid='chat-announcement-toggle'][aria-pressed='true']")

    click_on "Send"
    expect(page).to have_css("[data-testid='chat-pinned']", text: "Half a thought")
    expect(page).to have_css("[data-testid='chat-announcement-toggle'][aria-pressed='false']")
  end

  context "in the presenter" do
    before do
      create(:photo_submission, item: hunt.items.first, team:)
      hunt.update!(presentation_slide: "submission:#{hunt.submissions.first.id}")
    end

    it "shows the chat on a watcher's phone but never on the big screen" do
      visit "/scavenger_hunts/#{hunt.code}/presenter?screen=big"
      expect(page).to have_css("[data-testid='progress']")
      expect(page).not_to have_css("[data-testid='chat-pill']")

      visit "/scavenger_hunts/#{hunt.code}/presenter"
      expect(page).to have_css("[data-testid='chat-pill']")
      open_chat
      set_name("Eric")
      send_message("Great photo")
    end

    it "gives a watcher the organizer's chat controls when the remote is handed to them" do
      visit "/scavenger_hunts/#{hunt.code}/presenter"
      open_chat
      set_name("Eric")
      expect(page).to have_no_css("[data-testid='chat-announcement-toggle']")

      hunt.reload.hand_remote_to!(viewer_id)

      expect(page).to have_css("[data-testid='presenting']", text: "You have the remote")
      expect(page).to have_css("[data-testid='chat-announcement-toggle']")
      send_message("Taking it from here")
    end
  end

  it "stays hidden when the hunt turned chat off" do
    hunt.update!(chat_enabled: false)
    visit checklist_path(team)
    expect(page).to have_text("Tap an item")
    expect(page).not_to have_css("[data-testid='chat-pill']")
    expect(page).not_to have_css("[data-testid='organizer-card']")
  end

  it "can be switched off when creating a hunt" do
    visit "/"
    click_on "Start a hunt", match: :first
    first("[data-testid='template']").click
    fill_in("Hunt name", with: "Quiet Hunt")
    find("input#hunt_chat_enabled", visible: false).execute_script("this.checked = false")
    click_on "Create hunt"
    expect(page).to have_text("Quiet Hunt")
    expect(Hunt.last.chat_enabled).to be(false)
  end
end
