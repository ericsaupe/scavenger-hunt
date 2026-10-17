# frozen_string_literal: true

require "rails_helper"

RSpec.describe Message, :test_queue_adapter do
  let(:hunt) { create(:hunt) }

  it "keeps content between 1 and 280 characters" do
    expect(build(:message, hunt:, content: "")).not_to be_valid
    expect(build(:message, hunt:, content: "a" * 280)).to be_valid
    expect(build(:message, hunt:, content: "a" * 281)).not_to be_valid
  end

  it "needs a sender name of at most 40 characters" do
    expect(build(:message, hunt:, sender_name: nil)).not_to be_valid
    expect(build(:message, hunt:, sender_name: "n" * 40)).to be_valid
    expect(build(:message, hunt:, sender_name: "n" * 41)).not_to be_valid
  end

  it "is neither from the organizer nor an announcement unless flagged, and only announcements are pushed" do
    expect { create(:message, hunt:) }.not_to have_enqueued_job(AnnouncementJob)
    expect { create(:message, hunt:, organizer: true) }.not_to have_enqueued_job(AnnouncementJob)
    expect { create(:message, hunt:, organizer: true, announcement: true) }.to have_enqueued_job(AnnouncementJob)
    expect(hunt.messages.announcements.count).to eq(1)
  end

  it "pins the latest announcement, not the latest organizer message, and drops it when removed" do
    announcement = create(:message, hunt:, organizer: true, announcement: true)
    create(:message, hunt:, organizer: true)
    expect(hunt.latest_announcement).to eq(announcement)

    announcement.remove!

    expect(announcement.reload).to be_removed
    expect(described_class.visible).not_to include(announcement)
    expect(hunt.latest_announcement).to be_nil
  end

  it "removes a message from before names and limits existed" do
    legacy = create(:message, hunt:)
    legacy.update_columns(sender_name: nil, content: "x" * 400)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)

    expect { legacy.reload.remove! }.not_to raise_error

    expect(legacy.reload).to be_removed
    expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(hunt.chat_stream, hash_including(target: legacy)).once
  end

  it "shows the team initial, or the sender's when there is no team" do
    team = create(:team, hunt:, name: "blue bandits")
    expect(build(:message, hunt:, team:).initial).to eq("B")
    expect(build(:message, hunt:, sender_name: "eric").initial).to eq("E")
  end

  it "knows whose message it is" do
    message = build(:message, hunt:, user_id: "viewer")
    expect(message.own?("viewer")).to be(true)
    expect(message.own?("someone else")).to be(false)
    expect(message.own?(nil)).to be(false)
  end
end
