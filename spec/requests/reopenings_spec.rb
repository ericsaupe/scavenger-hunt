# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Reopening submissions" do
  include ActiveSupport::Testing::TimeHelpers

  let(:hunt) { create(:hunt, owner_id: "owner", ends_at: Time.zone.local(2026, 10, 30, 20, 0)) }
  let(:results_path) { "/scavenger_hunts/#{hunt.code}/results" }
  let(:reopening_path) { "/scavenger_hunts/#{hunt.code}/reopening" }

  before do
    travel_to Time.zone.local(2026, 10, 30, 20, 30)
    cookies[:user_id] = "owner"
  end

  def page
    Capybara.string(response.body)
  end

  describe "POST /reopening" do
    it "reopens submissions for the minutes the organizer picked" do
      post reopening_path, params: {minutes: "10"}

      expect(response).to redirect_to(results_path)
      expect(hunt.reload).to have_attributes(reopened_at: Time.zone.local(2026, 10, 30, 20, 30), ends_at: Time.zone.local(2026, 10, 30, 20, 40))
    end

    it "lets whoever has the remote reopen too" do
      hunt.update!(remote_holder_id: "phone")
      cookies[:user_id] = "phone"

      post reopening_path, params: {minutes: "25"}

      expect(hunt.reload.ends_at).to eq(Time.zone.local(2026, 10, 30, 20, 55))
    end

    it "refuses everyone else" do
      cookies[:user_id] = "guest"

      post reopening_path, params: {minutes: "10"}

      expect(response).to have_http_status(:forbidden)
      expect(hunt.reload).to have_attributes(reopened_at: nil, ends_at: Time.zone.local(2026, 10, 30, 20, 0))
    end

    it "sends the organizer back with a note for a length it can't use" do
      ["0", "121", "soon", ""].each do |minutes|
        post reopening_path, params: {minutes:}

        expect(response).to redirect_to(results_path)
        expect(flash[:warning]).to eq("Pick between 1 and 120 minutes")
      end
      expect(hunt.reload.reopened_at).to be_nil
    end
  end

  describe "PATCH /reopening" do
    it "adds five minutes while submissions are reopened" do
      hunt.reopen!(10.minutes)

      patch reopening_path

      expect(response).to redirect_to(results_path)
      expect(hunt.reload.ends_at).to eq(Time.zone.local(2026, 10, 30, 20, 45))
    end

    it "leaves a closed hunt closed" do
      patch reopening_path

      expect(hunt.reload.ends_at).to eq(Time.zone.local(2026, 10, 30, 20, 0))
    end

    it "refuses everyone else" do
      hunt.reopen!(10.minutes)
      cookies[:user_id] = "guest"

      patch reopening_path

      expect(response).to have_http_status(:forbidden)
      expect(hunt.reload.ends_at).to eq(Time.zone.local(2026, 10, 30, 20, 40))
    end
  end

  describe "DELETE /reopening" do
    it "closes submissions right away" do
      hunt.reopen!(10.minutes)
      travel 3.minutes

      delete reopening_path

      expect(response).to redirect_to(results_path)
      expect(hunt.reload.ends_at).to eq(Time.zone.local(2026, 10, 30, 20, 33))
    end

    it "refuses everyone else" do
      hunt.reopen!(10.minutes)
      cookies[:user_id] = "guest"

      delete reopening_path

      expect(response).to have_http_status(:forbidden)
      expect(hunt.reload.ends_at).to eq(Time.zone.local(2026, 10, 30, 20, 40))
    end
  end

  describe "the photo download" do
    let(:download_path) { "/scavenger_hunts/#{hunt.code}/download_results" }

    def attach_photo(submission)
      submission.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
    end

    def archive_blob
      hunt.reload.archive.blob
    end

    it "builds a fresh download once a photo or retake comes in after the last one" do
      first, second = create(:team, hunt:).submissions.order(:id).to_a
      attach_photo(first)
      get download_path
      before_reopening = archive_blob
      get download_path
      expect(archive_blob).to eq(before_reopening)

      travel 1.minute
      hunt.reopen!(10.minutes)
      attach_photo(second)
      get download_path
      during_reopening = archive_blob
      expect(during_reopening).not_to eq(before_reopening)
      expect(hunt.archive.open { |file| Zip::File.open(file.path, &:size) }).to eq(2)

      travel 1.minute
      attach_photo(first)
      get download_path
      expect(archive_blob).not_to eq(during_reopening)
    end
  end

  describe "the results page" do
    it "offers the organizer a reopen once the hunt is over" do
      get results_path

      expect(page).to have_css("[data-testid='reopen-card']", text: "Submissions closed at 8:00 PM")
      expect(page).to have_field("5 min", type: "radio", checked: false)
      expect(page).to have_field("10 min", type: "radio", checked: true)
      expect(page).to have_field("15 min", type: "radio", checked: false)
      expect(page).to have_field("Other", type: "radio", checked: false)
      expect(page).to have_field("Minutes", type: "number", disabled: true)
      expect(page).to have_button("Reopen for 10 minutes")
      expect(page).to have_css("form[action='#{reopening_path}'][method='post']")
    end

    it "keeps the reopen from everyone else, from running hunts and from hunts without an end" do
      cookies[:user_id] = "guest"
      get results_path
      expect(page).not_to have_css("[data-testid='reopen-card']")

      cookies[:user_id] = "owner"
      hunt.update!(ends_at: 1.hour.from_now)
      get results_path
      expect(page).not_to have_css("[data-testid='reopen-card']")

      hunt.update!(ends_at: nil)
      get results_path
      expect(page).not_to have_css("[data-testid='reopen-card']")
    end

    it "shows the organizer the countdown, the new photos and the controls while reopened" do
      first, second = create(:team, hunt:).submissions.order(:id).to_a
      first.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
      travel 1.minute
      hunt.reopen!(10.minutes)
      second.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")

      get results_path

      card = page.find("[data-testid='reopened-card']")
      expect(card).to have_text("10:00 left, closes at 8:41 PM", normalize_ws: true)
      expect(card).to have_text("1 photo in since you reopened")
      expect(card).to have_button("+ 5 min")
      expect(card).to have_button("Close now")
      expect(page).not_to have_css("[data-testid='reopen-card']")
    end

    it "keeps the controls above results that are hidden again" do
      hunt.update!(lock_results: true)
      hunt.reopen!(10.minutes)

      get results_path

      expect(page).to have_text("Results are not yet available!")
      expect(page).to have_css("[data-testid='reopened-card']")
    end

    it "tells everyone else submissions are open again" do
      hunt.reopen!(10.minutes)
      cookies[:user_id] = "guest"

      get results_path

      expect(page).not_to have_css("[data-testid='reopened-card']")
      expect(page).to have_css("[data-testid='reopened-note']", text: "Submissions are open again until 8:40 PM, so results can still change.")
    end
  end
end
