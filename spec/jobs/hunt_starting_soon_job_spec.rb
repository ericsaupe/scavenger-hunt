# frozen_string_literal: true

require "rails_helper"

RSpec.describe HuntStartingSoonJob do
  let(:hunt) { create(:hunt, starts_at: 5.minutes.from_now, ends_at: 2.hours.from_now) }

  it "tells every phone that wants to know that the hunt is about to start" do
    create_list(:push_subscription, 2, hunt:)
    create(:push_subscription, hunt:, notify_starting_soon: false)
    create(:push_subscription)

    described_class.perform_now(hunt, hunt.starts_at)

    expect(WebPush).to have_received(:payload_send).twice
    expect(pushed_messages.first).to include("title" => "#{hunt.name} starts in 5 minutes", "url" => "/scavenger_hunts/#{hunt.code}")
  end

  it "does nothing when the start time moved after it was scheduled" do
    create(:push_subscription, hunt:)

    described_class.perform_now(hunt, 1.hour.from_now)

    expect(WebPush).not_to have_received(:payload_send)
  end

  it "does nothing once the hunt has already started" do
    create(:push_subscription, hunt:)
    hunt.update!(starts_at: 1.minute.ago)

    described_class.perform_now(hunt, hunt.starts_at)

    expect(WebPush).not_to have_received(:payload_send)
  end

  it "prunes a phone whose subscription expired and carries on" do
    gone = create(:push_subscription, hunt:)
    alive = create(:push_subscription, hunt:)
    allow(WebPush).to receive(:payload_send).with(hash_including(endpoint: gone.endpoint)).and_raise(push_response_error(WebPush::ExpiredSubscription, 410))

    described_class.perform_now(hunt, hunt.starts_at)

    expect(PushSubscription.exists?(gone.id)).to be(false)
    expect(PushSubscription.exists?(alive.id)).to be(true)
    expect(WebPush).to have_received(:payload_send).with(hash_including(endpoint: alive.endpoint))
  end
end
