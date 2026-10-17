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

  def style_of(selector, property)
    find(selector).evaluate_script("getComputedStyle(this).#{property}")
  end

  def overlap?(selector, other, **options)
    rect = ->(element) { element.evaluate_script("this.getBoundingClientRect().toJSON()") }
    a = rect.call(find(selector))
    b = rect.call(find(other, **options))
    a["left"] < b["right"] && b["left"] < a["right"] && a["top"] < b["bottom"] && b["top"] < a["bottom"]
  end

  def emulate_phone(width, height)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride", width:, height:, deviceScaleFactor: 2, mobile: true)
    expect(page.evaluate_script("[window.innerWidth, window.innerHeight]")).to eq([width, height])
  end

  def box(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const rect = document.querySelector(#{selector.to_json}).getBoundingClientRect()
        return {top: rect.top, bottom: rect.bottom, left: rect.left, right: rect.right, viewport: window.innerHeight}
      })()
    JS
  end

  def on_screen?(rect)
    rect["top"] >= 0 && rect["bottom"] <= rect["viewport"]
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
    let!(:photo) { create(:photo_submission, item: hunt.items.first, team:) }

    before { hunt.update!(presentation_slide: "submission:#{photo.id}") }

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

    it "keeps the organizer's megaphone when another phone takes the remote" do
      visit "/scavenger_hunts/#{hunt.code}/presenter"
      hunt.update!(owner_id: viewer_id)
      visit "/scavenger_hunts/#{hunt.code}/presenter"
      expect(page).to have_css("#presenter_stream[connected]", visible: :all)
      open_chat
      set_name("Host")
      expect(page).to have_css("[data-testid='chat-announcement-toggle']")

      hunt.reload.hand_remote_to!("the host's phone")

      expect(page).to have_css("[data-testid='presenting']", text: "Someone else has the remote")
      expect(page).to have_css("[data-testid='chat-announcement-toggle']")
      find("[data-testid='chat-announcement-toggle']").click
      send_message("Still announcing from the laptop")
      expect(page).to have_css("[data-testid='chat-pinned']", text: "Still announcing from the laptop")
    end

    it "takes a stand-in host's chat controls away when they hand the remote over" do
      visit "/scavenger_hunts/#{hunt.code}/presenter"
      hunt.update!(remote_holder_id: viewer_id)
      create(:message, hunt:, content: "Who took the cones?", sender_name: "Dana", team: other_team)
      visit "/scavenger_hunts/#{hunt.code}/presenter"
      expect(page).to have_css("#presenter_stream[connected]", visible: :all)
      open_chat
      set_name("Host")
      expect(page).to have_css("[data-testid='chat-announcement-toggle']")
      expect(page).to have_css("[data-testid='chat-remove']", visible: :visible)

      hunt.reload.hand_remote_to!("someone else")

      expect(page).to have_no_css("[data-testid='chat-announcement-toggle']")
      expect(page).to have_no_css("[data-testid='chat-remove']", visible: :visible)
    end

    it "lets the host announce from the remote without leaving it" do
      visit "/scavenger_hunts/#{hunt.code}/presenter"
      click_on "Take the remote"
      expect(page).to have_current_path("/scavenger_hunts/#{hunt.code}/presenter/remote")
      expect(page).to have_css("turbo-cable-stream-source[connected]", visible: :all)
      expect(page).to have_css("[data-testid='chat-pill']")
      expect(page).to have_css("#party_chat_#{hunt.id} turbo-cable-stream-source[connected]", visible: :all)
      expect(page).to have_css("[data-chat-box][data-chat-organizer]", visible: :all)
      expect(find("[data-testid='chat-pill']")[:class]).to include("bottom-[max(1rem,env(safe-area-inset-bottom))]")
      expect(overlap?("[data-testid='chat-pill']", "button", text: "Next")).to be(false)

      open_chat
      find("[data-testid='chat-sheet'] button[aria-label='Close chat']", match: :first).send_keys(:arrow_right)
      expect(page).to have_css("[data-testid='progress']", text: "Item 1 of 3")
      expect(hunt.reload.presentation_slide).to eq("submission:#{hunt.submissions.first.id}")
      set_name("Host")
      expect(page).to have_text("Sending as Host, Organizer")
      find("[data-testid='chat-announcement-toggle']").click
      send_message("Pizza at 7 by the gazebo")
      expect(page).to have_css("[data-testid='chat-pinned']", text: "Pizza at 7 by the gazebo")
      expect(page).to have_css("[data-testid='chat-message'][data-announcement]", text: "Announcement")
      expect(page).to have_css("#party_chat_title_#{hunt.id}", text: "Party chat")
      expect(style_of("#party_chat_title_#{hunt.id}", "color")).to eq(style_of("[data-testid='chat-sheet'] strong", "color"))
      expect(hunt.messages.sole).to have_attributes(organizer: true, announcement: true, team: nil)

      find("[data-testid='chat-sheet'] button[aria-label='Close chat']", match: :first).click
      expect(page).not_to have_css("[data-testid='chat-sheet'].modal-open")
      find("body").send_keys(:arrow_right)
      expect(page).to have_css("[data-testid='progress']", text: "Photo 2 of 3")
      click_on "Next"
      expect(page).to have_css("[data-testid='progress']", text: "Finale 3 of 3")
      expect(page).to have_current_path("/scavenger_hunts/#{hunt.code}/presenter/remote")
      expect(page).to have_css("[data-testid='chat-pill']")
    end

    it "keeps the pill clear of the slide, the controls and the most-loved print on a phone" do
      create(:vote, submission: photo)
      visit "/scavenger_hunts/#{hunt.code}/presenter"
      emulate_phone(390, 844)
      expect(page).to have_css("#presenter_stream[connected]", visible: :all)
      expect(page).to have_css("[data-testid='photo-slide'] figure img[src]")

      pill = box("[data-testid='chat-pill']")
      expect(on_screen?(pill)).to be(true)
      expect(overlap?("[data-testid='chat-pill']", "[data-testid='photo-slide'] figure")).to be(false)

      hunt.reload.present!("finale")
      expect(page).to have_css("[data-testid='most-loved']")
      expect(overlap?("[data-testid='chat-pill']", "[data-testid='most-loved']")).to be(false)

      click_on "Previous"
      expect(page).to have_css("[data-testid='live-pill']", text: "Browsing")
      expect(page).to have_css("[data-testid='photo-slide'] figure img[src]")
      expect(page).to have_css("[data-testid='back-to-live']")

      pill = box("[data-testid='chat-pill']")
      back = box("[data-testid='back-to-live']")
      expect(overlap?("[data-testid='chat-pill']", "[data-testid='back-to-live']")).to be(false)
      expect(overlap?("[data-testid='chat-pill']", "[data-testid='photo-slide'] figure")).to be(false)
      expect(on_screen?(pill)).to be(true)
      expect(on_screen?(back)).to be(true)
      expect(on_screen?(box("a[aria-label='Previous slide']"))).to be(true)
      expect(on_screen?(box("a[aria-label='Next slide']"))).to be(true)

      open_chat
    ensure
      page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
    end

    it "reloads the chat for a handover that lands before the sheet has loaded" do
      visit "/scavenger_hunts/#{hunt.code}/presenter"
      expect(page).to have_css("#presenter_stream[connected]", visible: :all)
      expect(page).to have_css("[data-chat-box]", visible: :all)
      page.execute_script("document.querySelector('[data-chat-box]').remove()")

      hunt.reload.hand_remote_to!(viewer_id)

      expect(page).to have_css("[data-testid='presenting']", text: "You have the remote")
      open_chat
      set_name("Eric")
      expect(page).to have_css("[data-testid='chat-announcement-toggle']")
    end
  end

  it "lets an organizer chat from the hunt page without borrowing a team's name" do
    visit checklist_path(team)
    hunt.update!(owner_id: viewer_id)
    visit checklist_path(team)
    expect(page).to have_css("[data-testid='chat-pill'].bottom-4")
    click_on "Teams"
    expect(page).to have_button("Join the hunt")
    expect(page).to have_css("[data-testid='chat-pill'].bottom-24")
    expect(overlap?("[data-testid='chat-pill']", ".bottom-bar")).to be(false)

    open_chat
    set_name("Host")
    expect(page).to have_text("Sending as Host, Organizer")
    send_message("Welcome, everyone")
    within("[data-testid='chat-message']") do
      expect(page).to have_text("Organizer")
      expect(page).not_to have_text("Blue Bandits")
    end

    using_session(:other) do
      visit "/scavenger_hunts/#{hunt.code}"
      expect(page).to have_button("Join the hunt")
      expect(page).not_to have_css("[data-testid='chat-pill']")

      visit "/scavenger_hunts/#{hunt.code}/results"
      expect(page).to have_css("[data-testid='chat-unread']", text: "1")
      open_chat
      expect(page).to have_css("[data-testid='chat-message']:not([data-own])", text: "Welcome, everyone")
      expect(page).not_to have_css("[data-testid='chat-announcement-toggle']")
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
