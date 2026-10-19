# frozen_string_literal: true

require "rails_helper"

RSpec.describe Hunt do
  context "associations" do
    it { is_expected.to have_many(:categories).class_name("Category") }
    it { is_expected.to have_many(:items).class_name("Item") }
    it { is_expected.to have_many(:teams).class_name("Team") }
  end

  it "sets code on create" do
    hunt = described_class.new(name: "Test")
    expect(hunt.code).to be_nil
    hunt.save!
    expect(hunt.code).not_to be_nil
  end

  it "does not replace code if one is present" do
    hunt = described_class.new(name: "Test", code: "TEST")
    expect(hunt.code).to eq("TEST")
    hunt.save!
    expect(hunt.code).to eq("TEST")
  end

  describe "#results" do
    let(:hunt) { create(:hunt) }

    def find(team, item, denied: false)
      submission = team.submissions.find_by(item:)
      submission.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
      submission.update!(denied_points: denied)
    end

    it "ranks teams by score with their totals, deductions and found counts" do
      hunt.categories.first.update!(points: 5)
      first_item, second_item, third_item = hunt.items.order(:id).to_a
      trailers = create(:team, hunt:, name: "Trailers")
      leaders = create(:team, hunt:, name: "Leaders")
      create(:team, hunt:, name: "Empty")
      [first_item, second_item, third_item].each { |item| find(leaders, item) }
      find(trailers, first_item)
      find(trailers, second_item)
      find(trailers, third_item, denied: true)

      results = hunt.results

      expect(results.map { |result| result.except(:victory_photo_url, :team_id, :team) }).to eq([
        {name: "Leaders", score: 15, total_score: 15, deductions: 0, submissions: 3},
        {name: "Trailers", score: 10, total_score: 15, deductions: 5, submissions: 3},
        {name: "Empty", score: 0, total_score: 0, deductions: 0, submissions: 0}
      ])
      expect(results.first[:victory_photo_url]).to start_with("/rails/active_storage/representations/redirect/")
    end
  end

  describe "#create_archive_file" do
    before { allow(ActiveStorage::Current).to receive(:url_options).and_return(host: "localhost:3000") }

    it "names each file after its item with an extension matching its type" do
      hunt = create(:hunt, name: "Summer Hunt")
      team = create(:team, hunt:, name: "Red Team")
      hunt.items.first.update!(name: "Sandcastle")
      hunt.items.second.update!(name: "Seagull")
      create(:photo_submission, team:, item: hunt.items.first)
      create(:video_submission, team:, item: hunt.items.second)

      hunt.create_archive_file

      names = hunt.archive.open { |file| Zip::File.open(file.path) { |zip| zip.map(&:name) } }
      expect(names).to contain_exactly("Summer Hunt/Red Team/Sandcastle.jpg", "Summer Hunt/Red Team/Seagull.mp4")
    end

    it "stores each file unchanged and cleans up the working file" do
      hunt = create(:hunt)
      team = create(:team, hunt:)
      create(:photo_submission, team:, item: hunt.items.first)
      create(:video_submission, team:, item: hunt.items.second)

      hunt.create_archive_file

      contents = hunt.archive.open { |file| Zip::File.open(file.path) { |zip| zip.map { |entry| zip.read(entry) } } }
      expect(contents).to contain_exactly(
        Rails.root.join("spec/fixtures/test.jpg").binread,
        Rails.root.join("spec/fixtures/video.mp4").binread
      )
      expect(Rails.root.join("tmp", "archive-#{hunt.id}.zip")).not_to exist
    end

    it "replaces characters that cannot be used in file names" do
      hunt = create(:hunt, name: "Bob's \"Big\" Hunt: Part 2")
      team = create(:team, hunt:, name: "Red/Blue")
      hunt.items.first.update!(name: "Camper / RV")
      hunt.items.second.update!(name: "The word \"Boo\"?")
      create(:photo_submission, team:, item: hunt.items.first)
      create(:video_submission, team:, item: hunt.items.second)

      hunt.create_archive_file

      names = hunt.archive.open { |file| Zip::File.open(file.path) { |zip| zip.map(&:name) } }
      expect(names).to contain_exactly(
        "Bob's 'Big' Hunt- Part 2/Red-Blue/Camper - RV.jpg",
        "Bob's 'Big' Hunt- Part 2/Red-Blue/The word 'Boo'-.mp4"
      )
    end
  end

  describe "#in_progress?" do
    let(:hunt) { create(:hunt) }

    describe "when true" do
      it "has no dates set" do
        expect(hunt).to be_in_progress
      end

      it "starts in the past" do
        hunt.update(starts_at: 1.day.ago)
        expect(hunt).to be_in_progress
      end

      it "ends in the past" do
        hunt.update(ends_at: 1.day.from_now)
        expect(hunt).to be_in_progress
      end

      it "is between the start and end" do
        hunt.update(starts_at: 1.day.ago, ends_at: 1.day.from_now)
        expect(hunt).to be_in_progress
      end
    end

    describe "when false" do
      it "starts in the future" do
        hunt.update(starts_at: 1.day.from_now)
        expect(hunt).not_to be_in_progress
      end

      it "ends in the past" do
        hunt.update(ends_at: 1.day.ago)
        expect(hunt).not_to be_in_progress
      end
    end
  end

  describe "#results_locked?" do
    let(:hunt) { create(:hunt) }

    describe "when true" do
      it "is true when a password is present and not entered yet" do
        hunt.update(ends_at: nil, password: "hunter2", password_entered: false)
        expect(hunt).to be_results_locked
        hunt.update(ends_at: 1.month.ago, password: "hunter2", password_entered: false)
        expect(hunt).to be_results_locked
      end

      it "is true when the end is in the future and results are locked" do
        hunt.update(ends_at: 1.month.from_now, lock_results: true)
        expect(hunt).to be_results_locked
      end
    end

    describe "when false" do
      it "is false when there is a password and it has been entered" do
        hunt.update(password: "hunter2", password_entered: true)
        expect(hunt).not_to be_results_locked
      end

      it "is false when the end is in the past and no password" do
        hunt.update(ends_at: 1.month.ago, lock_results: true)
        expect(hunt).not_to be_results_locked
      end

      it "is false by default" do
        expect(hunt).not_to be_results_locked
      end
    end
  end
end

RSpec.describe Hunt, "reopening submissions" do
  include ActiveSupport::Testing::TimeHelpers

  let(:hunt) { create(:hunt, ends_at: Time.zone.local(2026, 10, 30, 20, 0)) }

  before { travel_to Time.zone.local(2026, 10, 30, 20, 30) }

  def attach_photo(submission)
    submission.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
  end

  it "opens an ended hunt back up for the chosen time" do
    expect(hunt.reopen!(10.minutes)).to be(true)

    expect(hunt.reload).to have_attributes(reopened_at: Time.zone.local(2026, 10, 30, 20, 30), ends_at: Time.zone.local(2026, 10, 30, 20, 40))
    expect(hunt).to be_reopened
    expect(hunt).to be_in_progress
    expect(hunt.accepts_photo_captured_at?(nil)).to be(true)
  end

  it "only reopens a hunt that has ended" do
    running = create(:hunt, ends_at: 1.hour.from_now)
    endless = create(:hunt)

    expect(running.reopen!(10.minutes)).to be(false)
    expect(endless.reopen!(10.minutes)).to be(false)
    expect(running.reload).to have_attributes(reopened_at: nil, ends_at: Time.zone.local(2026, 10, 30, 21, 30))
    expect(endless.reload).to have_attributes(reopened_at: nil, ends_at: nil)
    expect(running).not_to be_reopened
  end

  it "keeps the length between a minute and two hours" do
    expect(hunt.reopen!(0.minutes)).to be(false)
    expect(hunt.reopen!(121.minutes)).to be(false)
    expect(hunt.reload).to be_ended

    expect(hunt.reopen!(2.hours)).to be(true)
    expect(hunt.reload.ends_at).to eq(Time.zone.local(2026, 10, 30, 22, 30))
  end

  it "adds time and closes early only while reopened" do
    expect(hunt.add_reopened_time!(5.minutes)).to be(false)
    expect(hunt.close_reopened!).to be(false)
    expect(hunt.reload.ends_at).to eq(Time.zone.local(2026, 10, 30, 20, 0))

    hunt.reopen!(10.minutes)
    expect(hunt.add_reopened_time!(5.minutes)).to be(true)
    expect(hunt.reload.ends_at).to eq(Time.zone.local(2026, 10, 30, 20, 45))

    travel 2.minutes
    expect(hunt.close_reopened!).to be(true)
    expect(hunt.reload.ends_at).to eq(Time.zone.local(2026, 10, 30, 20, 32))
    travel 1.second
    expect(hunt).to be_ended
    expect(hunt).not_to be_reopened
  end

  it "gives photos still uploading the usual grace from the reopened close" do
    hunt.reopen!(10.minutes)
    travel_to Time.zone.local(2026, 10, 30, 20, 50)

    expect(hunt).not_to be_reopened
    expect(hunt.accepts_photo_captured_at?(Time.zone.local(2026, 10, 30, 20, 39))).to be(true)
    expect(hunt.accepts_photo_captured_at?(Time.zone.local(2026, 10, 30, 20, 41))).to be(false)
  end

  it "hides locked results again until the reopened time closes" do
    hunt.update!(lock_results: true)
    expect(hunt).not_to be_results_locked

    hunt.reopen!(10.minutes)

    expect(hunt).to be_results_locked
  end

  it "counts the photos and retakes that came in since it reopened" do
    first, second, third = create(:team, hunt:).submissions.order(:id).to_a
    attach_photo(first)
    attach_photo(second)

    travel 1.minute
    hunt.reopen!(10.minutes)
    travel 1.minute
    attach_photo(second)
    attach_photo(third)

    expect(hunt.reopened_photo_count).to eq(2)
  end

  it "tells phones submissions are open again and sends the results alert after the new close", :test_queue_adapter do
    hunt.reopen!(10.minutes, by: "organizer")

    expect(SubmissionsReopenedJob).to have_been_enqueued.with(hunt, "organizer")
    expect(HuntResultsReadyJob).to have_been_enqueued.with(hunt, Time.zone.local(2026, 10, 30, 20, 40)).at(Time.zone.local(2026, 10, 30, 20, 55))
  end
end

RSpec.describe Hunt, "notifications", :test_queue_adapter do
  include ActiveSupport::Testing::TimeHelpers

  describe "scheduling" do
    it "queues the starting soon reminder five minutes before the start" do
      starts_at = 2.hours.from_now.change(usec: 0)
      hunt = create(:hunt, starts_at:)

      expect(HuntStartingSoonJob).to have_been_enqueued.with(hunt, starts_at).at(starts_at - 5.minutes)
    end

    it "queues another reminder when the start time changes" do
      hunt = create(:hunt, starts_at: 2.hours.from_now)
      later = 3.hours.from_now.change(usec: 0)

      hunt.update!(starts_at: later)

      expect(HuntStartingSoonJob).to have_been_enqueued.with(hunt, later).at(later - 5.minutes)
    end

    it "does not queue a reminder for a hunt starting in under five minutes" do
      create(:hunt, starts_at: 3.minutes.from_now)

      expect(HuntStartingSoonJob).not_to have_been_enqueued
    end

    it "queues the results notification once the grace window closes" do
      ends_at = 2.hours.from_now.change(usec: 0)
      hunt = create(:hunt, ends_at:)

      expect(HuntResultsReadyJob).to have_been_enqueued.with(hunt, ends_at).at(ends_at + Hunt::LATE_UPLOAD_GRACE)
    end

    it "does not queue results for an end that has already passed" do
      create(:hunt, ends_at: 1.hour.ago)

      expect(HuntResultsReadyJob).not_to have_been_enqueued
    end
  end

  describe "#schedule_notifications" do
    it "queues both reminders for a hunt that already existed when reminders arrived" do
      starts_at = 1.hour.from_now.change(usec: 0)
      ends_at = 3.hours.from_now.change(usec: 0)
      hunt = create(:hunt)
      hunt.update_columns(starts_at:, ends_at:)

      hunt.schedule_notifications

      expect(HuntStartingSoonJob).to have_been_enqueued.with(hunt, starts_at).at(starts_at - 5.minutes)
      expect(HuntResultsReadyJob).to have_been_enqueued.with(hunt, ends_at).at(ends_at + Hunt::LATE_UPLOAD_GRACE)
    end
  end

  describe "#announce_show!" do
    let(:hunt) { create(:hunt) }

    it "announces the show the first time only" do
      hunt.announce_show!
      hunt.announce_show!
      described_class.find(hunt.id).announce_show!

      expect(ShowStartingJob).to have_been_enqueued.with(hunt).once
      expect(hunt.show_announced_at).to be_present
    end

    it "is triggered by claiming the remote and by showing a slide" do
      claimed = create(:hunt)
      claimed.hand_remote_to!("host")
      expect(ShowStartingJob).to have_been_enqueued.with(claimed).once

      team = create(:team, hunt:)
      submission = team.submissions.first
      submission.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
      allow(hunt).to receive(:broadcast_presentation_update)
      hunt.present!(submission.id)
      expect(ShowStartingJob).to have_been_enqueued.with(hunt).once
    end
  end

  describe "organizer and remote holder" do
    let(:hunt) { create(:hunt, owner_id: "laptop") }

    it "keeps the organizer when the remote is handed to another device" do
      allow(hunt).to receive(:broadcast_presentation_update)

      hunt.hand_remote_to!("phone")

      expect(hunt).to have_attributes(owner_id: "laptop", remote_holder_id: "phone")
      expect(hunt.owner?("laptop")).to be(true)
      expect(hunt.owner?("phone")).to be(false)
      expect(hunt.remote_holder?("phone")).to be(true)
      expect(hunt.remote_holder?("laptop")).to be(false)
    end

    it "treats the owner and the current remote holder as organizers" do
      hunt.update!(remote_holder_id: "phone")

      expect(hunt.organizer?("laptop")).to be(true)
      expect(hunt.organizer?("phone")).to be(true)
      expect(hunt.organizer?("guest")).to be(false)
      expect(hunt.organizer?(nil)).to be(false)
    end

    it "never mistakes a missing cookie for an ownerless hunt's organizer" do
      hunt.update!(owner_id: nil)

      expect(hunt.owner?(nil)).to be(false)
      expect(hunt.organizer?("")).to be(false)
      expect(hunt.remote_held?).to be(false)
    end
  end

  describe "#leader" do
    let(:hunt) { create(:hunt) }

    def find(team, item)
      team.submissions.find_by(item:).photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
    end

    it "is nobody until a team is alone on top" do
      hunt.categories.first.update!(points: 5)
      reds = create(:team, hunt:, name: "Reds")
      blues = create(:team, hunt:, name: "Blues")
      expect(hunt.leader).to be_nil

      find(reds, hunt.items.first)
      expect(hunt.leader).to eq([reds, 5])

      find(blues, hunt.items.first)
      expect(hunt.leader).to be_nil
    end
  end
end
