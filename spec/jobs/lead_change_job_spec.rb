# frozen_string_literal: true

require "rails_helper"

RSpec.describe LeadChangeJob, :test_queue_adapter do
  include ActiveSupport::Testing::TimeHelpers

  let(:hunt) { create(:hunt) }
  let(:items) { hunt.items.order(:id).to_a }
  let!(:reds) { create(:team, hunt:, name: "Reds") }
  let!(:blues) { create(:team, hunt:, name: "Blues") }

  before { hunt.categories.first.update!(points: 5) }

  def find(team, item)
    team.submissions.find_by(item:).photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")
  end

  it "announces the team that took the lead" do
    create(:push_subscription, hunt:)
    create(:push_subscription, hunt:, notify_lead_change: false)
    find(reds, items.first)

    described_class.perform_now(hunt)

    expect(WebPush).to have_received(:payload_send).once
    expect(pushed_messages.first).to include("title" => "Reds takes the lead", "body" => "Reds is on top of the #{hunt.name} leaderboard with 5 points.",
      "url" => "/scavenger_hunts/#{hunt.code}/results", "tag" => "lead_change-#{hunt.id}")
    expect(hunt.reload).to have_attributes(leading_team_id: reds.id, lead_announced_at: be_within(1.second).of(Time.current))
  end

  it "stays quiet while the same team leads, nobody has scored, or two teams are tied" do
    create(:push_subscription, hunt:)
    described_class.perform_now(hunt)
    find(reds, items.first)
    described_class.perform_now(hunt)
    find(reds, items.second)
    described_class.perform_now(hunt)
    find(blues, items.first)
    find(blues, items.second)
    described_class.perform_now(hunt)

    expect(WebPush).to have_received(:payload_send).once
  end

  it "waits five minutes between announcements and then checks again once" do
    create(:push_subscription, hunt:)
    find(reds, items.first)
    described_class.perform_now(hunt)

    travel 2.minutes
    find(blues, items.first)
    find(blues, items.second)
    described_class.perform_now(hunt)
    described_class.perform_now(hunt)

    expect(WebPush).to have_received(:payload_send).once
    expect(hunt.reload.leading_team_id).to eq(reds.id)
    expect(LeadChangeJob).to have_been_enqueued.with(hunt).at(hunt.lead_announced_at + 5.minutes).once

    travel 3.minutes + 1.second
    described_class.perform_now(hunt)

    expect(WebPush).to have_received(:payload_send).twice
    expect(pushed_messages.last["title"]).to eq("Blues takes the lead")
    expect(hunt.reload).to have_attributes(leading_team_id: blues.id, lead_recheck_at: nil)
  end

  it "does not give away a hidden leaderboard" do
    create(:push_subscription, hunt:)
    hunt.update!(lock_results: true, ends_at: 1.hour.from_now)
    find(reds, items.first)

    described_class.perform_now(hunt)

    expect(WebPush).not_to have_received(:payload_send)
  end

  it "runs when a photo is attached or points are taken away, not on every touch" do
    find(reds, items.first)
    expect(LeadChangeJob).to have_been_enqueued.with(hunt).once

    reds.submissions.find_by(item: items.first).update!(denied_points: true)
    expect(LeadChangeJob).to have_been_enqueued.with(hunt).twice

    reds.submissions.find_by(item: items.first).touch
    expect(LeadChangeJob).to have_been_enqueued.with(hunt).twice
  end

  it "prunes a phone that is gone" do
    gone = create(:push_subscription, hunt:)
    allow(WebPush).to receive(:payload_send).and_raise(push_response_error(WebPush::ExpiredSubscription, 410))
    find(reds, items.first)

    described_class.perform_now(hunt)

    expect(PushSubscription.exists?(gone.id)).to be(false)
  end
end
