# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Push notification opt-in", :secure_origin do
  let(:hunt) { create(:hunt) }

  def pretend_permission(state)
    page.execute_script("Object.defineProperty(Notification, 'permission', { get: () => arguments[0], configurable: true })", state)
  end

  after do
    page.execute_script("localStorage.removeItem('pushPromptPending'); localStorage.removeItem('pushPromptDismissed')")
  end

  def revisit(path)
    page.execute_script("window.Turbo.visit(arguments[0], { action: 'replace' })", path)
  end

  it "never asks in the plain browser, even on hunt pages" do
    visit "/scavenger_hunts/#{hunt.code.upcase}"

    expect(page).to have_text("Pick your team")
    expect(page).not_to have_text("Get a heads-up during the hunt")
    expect(page).not_to have_css("[data-testid='notification-settings']", visible: :visible)
  end

  it "asks once the app has been installed and remembers Not now" do
    visit "/scavenger_hunts/#{hunt.code.upcase}"
    pretend_permission("default")
    page.execute_script("localStorage.setItem('pushPromptPending', 'true')")

    revisit "/scavenger_hunts/#{hunt.code.upcase}"
    expect(page).to have_text("Get a heads-up during the hunt")
    click_on "Not now"
    expect(page).not_to have_text("Get a heads-up during the hunt")

    revisit "/scavenger_hunts/#{hunt.code.upcase}"
    expect(page).to have_text("Pick your team")
    expect(page).not_to have_text("Get a heads-up during the hunt")
    expect(page.evaluate_script("localStorage.getItem('pushPromptPending')")).to be_nil
    expect(page.evaluate_script("localStorage.getItem('pushPromptDismissed')")).to eq("true")
  end

  it "asks right after the install prompt is accepted" do
    team = create(:team, hunt:)
    visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
    pretend_permission("default")
    page.execute_script("window.dispatchEvent(Object.assign(new Event('beforeinstallprompt'), { prompt() {}, userChoice: Promise.resolve({ outcome: 'accepted' }) }))")

    click_on "Install"

    expect(page).to have_text("Get a heads-up during the hunt")
    expect(page).not_to have_text("Add Scavenger Hunt Party to your home screen")
  end

  it "does not ask a phone that already refused notifications" do
    team = create(:team, hunt:)
    visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
    pretend_permission("denied")
    page.execute_script("window.dispatchEvent(Object.assign(new Event('beforeinstallprompt'), { prompt() {}, userChoice: Promise.resolve({ outcome: 'accepted' }) }))")

    click_on "Install"

    expect(page).not_to have_text("Add Scavenger Hunt Party to your home screen")
    expect(page).not_to have_text("Get a heads-up during the hunt")
  end
end
