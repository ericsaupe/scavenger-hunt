# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Offline" do
  let(:hunt) { create(:hunt, ends_at: 1.hour.from_now) }
  let(:team) { create(:team, hunt:) }
  let(:item) { hunt.items.first }
  let(:team_path) { "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}" }

  def choose_photo
    attach_file(Rails.root.join("spec/fixtures/test.jpg")) do
      find(:button, text: item.name).click
      click_on "Choose from your photos"
    end
  end

  describe "with the service worker installed", :secure_origin do
    before do
      visit team_path
      clear_upload_queue
      wait_for_service_worker
      expect(wait_for_page_cached).to be(true)
    end

    after { forget_service_worker }

    it "opens the checklist from cache when offline and keeps the countdown running" do
      go_offline
      visit team_path

      expect(page).to have_text(team.name)
      expect(page).to have_text(item.name)
      expect(page).to have_text(/Offline, last synced at \d+:\d\d/)
      expect(page).to have_text(/Ends in 59m \d\ds/)
    end

    it "hides the offline banner again once the page comes back from the network" do
      go_offline
      visit team_path
      expect(page).to have_text("Offline, last synced at")

      go_online
      page.execute_script("window.dispatchEvent(new Event('online'))")

      expect(page).not_to have_text("Offline, last synced at")
    end

    it "keeps a queued photo across a reload without signal" do
      go_offline
      choose_photo
      expect(page).to have_css("li[data-queued]")

      visit team_path

      expect(page).to have_text("Offline, last synced at")
      expect(page).to have_css("li[data-queued] img")
      expect(page).to have_text("Will upload when you have signal")
    end
  end

  describe "the capture queue" do
    before do
      visit team_path
      clear_upload_queue
    end

    it "queues a photo taken without signal and uploads it when signal returns" do
      go_offline
      choose_photo

      expect(page).to have_css("li[data-queued] img")
      expect(page).to have_css("[data-testid='queued-badge']")
      expect(page).to have_text("Will upload when you have signal")
      expect(team.submissions.find_by(item:).photo).not_to be_attached

      go_online

      expect(page).to have_css("li[data-found]", wait: 15)
      expect(page).not_to have_text("Will upload when you have signal")
      submission = team.submissions.find_by(item:)
      expect(submission.photo).to be_attached
      expect(submission.captured_at).to be_within(1.minute).of(Time.current)
    end

    it "sends only the last photo chosen for an item while offline" do
      go_offline
      choose_photo
      expect(page).to have_css("li[data-queued]")
      choose_photo
      expect(page).to have_css("li[data-queued]")
      expect(page.evaluate_async_script(<<~JS)).to eq(1)
        const done = arguments[0]
        const request = indexedDB.open("scavenger-hunt-party")
        request.onsuccess = () => {
          const count = request.result.transaction("queued_uploads").objectStore("queued_uploads").count()
          count.onsuccess = () => done(count.result)
        }
      JS

      go_online

      expect(page).to have_css("li[data-found]", wait: 10)
      expect(page).not_to have_text("A teammate already found")
    end

    it "shows a queued retake on a found row" do
      team.submissions.find_by(item:).photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "first.jpg")
      visit team_path
      clear_upload_queue
      expect(page).to have_css("li[data-found]")

      go_offline
      attach_file("submission_#{team.submissions.find_by(item:).id}_photo", Rails.root.join("spec/fixtures/test.jpg"), make_visible: true)

      expect(page).to have_css("li[data-found][data-queued]")
      expect(page).to have_text("Will upload when you have signal")
    end

    it "keeps a teammate's photo that landed first and says so" do
      go_offline
      choose_photo
      expect(page).to have_css("li[data-queued]")

      submission = team.submissions.find_by(item:)
      submission.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "teammate.jpg")
      teammate_blob = submission.reload.photo.blob

      go_online

      expect(page).to have_text("A teammate already found #{item.name}", wait: 10)
      expect(page).to have_css("li[data-found]")
      expect(submission.reload.photo.blob).to eq(teammate_blob)
    end

    it "shows the server's refusal on the row when the grace window has passed" do
      go_offline
      choose_photo
      expect(page).to have_css("li[data-queued]")

      hunt.update!(ends_at: Hunt::LATE_UPLOAD_GRACE.ago - 1.minute)
      go_online

      expect(page).to have_text("The hunt ended before this photo was sent", wait: 10)
      expect(find("li[data-item='#{item.id}']")).to have_text("The hunt ended before this photo was sent")
      expect(page).not_to have_css("li[data-queued]")
      expect(page).not_to have_css("li[data-found]")
      expect(team.submissions.find_by(item:).photo).not_to be_attached
    end
  end

  describe "the install prompt" do
    it "appears on the home page once the browser offers to install, and stays dismissed" do
      visit "/"
      expect(page).not_to have_text("Add Scavenger Hunt Party to your home screen")

      page.execute_script("window.dispatchEvent(Object.assign(new Event('beforeinstallprompt'), { prompt() {}, userChoice: Promise.resolve({ outcome: 'dismissed' }) }))")

      expect(page).to have_text("Add Scavenger Hunt Party to your home screen")
      click_on "Not now"
      expect(page).not_to have_text("Add Scavenger Hunt Party to your home screen")

      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      expect(page).to have_text(item.name)
      expect(page).not_to have_text("Add Scavenger Hunt Party to your home screen")
    end

    it "stays out of the way of pages with a bottom bar" do
      visit "/scavenger_hunts/new"
      page.execute_script("window.dispatchEvent(Object.assign(new Event('beforeinstallprompt'), { prompt() {}, userChoice: Promise.resolve({ outcome: 'dismissed' }) }))")

      expect(page).to have_button("Create hunt")
      expect(page).not_to have_css("[data-testid='install-prompt']")
    end
  end
end
