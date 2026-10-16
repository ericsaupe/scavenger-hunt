# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Uploads" do
  let(:hunt) { create(:hunt) }
  let(:team) { create(:team, hunt:) }
  let(:item) { hunt.items.first }

  before { visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}" }

  def choose_photo
    attach_file(Rails.root.join("spec/fixtures/test.jpg")) do
      find(:label, text: item.name).click
    end
  end

  def set_direct_upload_url(url)
    page.execute_script("document.querySelectorAll('[data-direct-upload-url]').forEach((field) => field.dataset.directUploadUrl = #{url.to_json})")
  end

  it "shows a pending print and then the found state" do
    page.execute_script(<<~JS)
      const send = XMLHttpRequest.prototype.send
      XMLHttpRequest.prototype.send = function (...args) { setTimeout(() => send.apply(this, args), 1500) }
    JS

    choose_photo

    expect(page).to have_css("li[data-uploading] img")
    expect(page).to have_css("li[data-found]", wait: 10)
    expect(team.submissions.find_by(item:).photo).to be_attached
  end

  it "keeps the pending print while retrying and offers to try again when the upload keeps failing" do
    set_direct_upload_url("/rails/active_storage/direct_uploads/unreachable")

    choose_photo

    expect(page).to have_css("li[data-uploading] img")
    expect(page).to have_button("Try again", wait: 10)
    expect(page).to have_text("couldn't be uploaded")
    expect(page).not_to have_css("li[data-found]")

    set_direct_upload_url("/rails/active_storage/direct_uploads")
    click_on "Try again"

    expect(page).to have_css("li[data-found]", wait: 10)
  end

  it "offers to try again when the final save does not reach the server" do
    page.execute_script(<<~JS)
      window.realFetch = window.fetch
      window.fetch = (url, options) => String(url).includes("/submissions/") ? Promise.reject(new TypeError("Failed to fetch")) : window.realFetch(url, options)
    JS

    choose_photo

    expect(page).to have_button("Try again", wait: 10)
    expect(page).not_to have_css("li[data-found]")

    page.execute_script("window.fetch = window.realFetch")
    click_on "Try again"

    expect(page).to have_css("li[data-found]", wait: 10)
  end

  it "offers to try again when the server answers the final save with an error page" do
    page.execute_script(<<~JS)
      window.realFetch = window.fetch
      window.fetch = (url, options) => String(url).includes("/submissions/") ? Promise.resolve(new Response("Service Unavailable", { status: 503 })) : window.realFetch(url, options)
    JS

    choose_photo

    expect(page).to have_button("Try again", wait: 10)
    expect(page).not_to have_css("li[data-found]")

    page.execute_script("window.fetch = window.realFetch")
    click_on "Try again"

    expect(page).to have_css("li[data-found]", wait: 10)
  end

  it "uploads the original photo when the browser cannot decode it for compression" do
    page.execute_script(<<~JS)
      window.createImageBitmap = () => Promise.reject(new Error("undecodable"))
      Object.defineProperty(HTMLImageElement.prototype, "src", { set() {} })
    JS

    choose_photo

    expect(page).to have_css("li[data-found]", wait: 10)
  end

  it "ignores a second file chosen while the first is still being checked" do
    page.execute_script(<<~JS)
      Object.defineProperty(HTMLMediaElement.prototype, "src", { set() {} })
    JS
    attach_file(Rails.root.join("spec/fixtures/video.mp4")) do
      find(:label, text: item.name).click
    end

    choose_photo
    sleep 2

    expect(page).not_to have_css("li[data-uploading]")
    expect(page).not_to have_css("li[data-found]")
    expect(team.submissions.find_by(item:).photo).not_to be_attached
  end

  it "refuses a video that is too long before uploading it" do
    page.execute_script(<<~JS)
      Object.defineProperty(HTMLMediaElement.prototype, "duration", { get: () => 31 })
    JS

    attach_file(Rails.root.join("spec/fixtures/video.mp4")) do
      find(:label, text: item.name).click
    end

    expect(page).to have_text("Videos must be 30 seconds or shorter")
    expect(page).not_to have_css("li[data-uploading]")
    expect(page).not_to have_css("li[data-found]")
  end

  it "accepts a photo whose upload crosses the hunt's end" do
    hunt.update!(ends_at: 4.seconds.from_now)
    visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
    page.execute_script(<<~JS)
      const send = XMLHttpRequest.prototype.send
      XMLHttpRequest.prototype.send = function (...args) { setTimeout(() => send.apply(this, args), 3000) }
    JS

    choose_photo

    expect(page).to have_text("Hunt over", wait: 10)
    expect(page).to have_css("li[data-found]", wait: 20)
  end

  it "tells the team when the hunt ended before the photo was sent" do
    hunt.update!(ends_at: 1.day.ago)

    choose_photo

    expect(page).to have_text("The hunt ended before this photo was sent")
    expect(page).not_to have_css("li[data-found]")
    expect(page).not_to have_css("li[data-uploading]")
  end
end
