# frozen_string_literal: true

require "rails_helper"

RSpec.describe HuntResultsReadyJob do
  let(:hunt) { create(:hunt, ends_at: 20.minutes.ago) }

  it "tells phones the hunt is over and points them at the results" do
    create(:push_subscription, hunt:)
    create(:push_subscription, hunt:, notify_results: false)

    described_class.perform_now(hunt, hunt.ends_at)

    expect(WebPush).to have_received(:payload_send).once
    expect(pushed_messages.first).to include("title" => "#{hunt.name} is over", "url" => "/scavenger_hunts/#{hunt.code}/results")
  end

  it "does nothing when the end time moved after it was scheduled" do
    create(:push_subscription, hunt:)

    described_class.perform_now(hunt, 1.hour.from_now)

    expect(WebPush).not_to have_received(:payload_send)
  end

  it "does nothing if the hunt is somehow still running" do
    create(:push_subscription, hunt:)
    hunt.update!(ends_at: 1.hour.from_now)

    described_class.perform_now(hunt, hunt.ends_at)

    expect(WebPush).not_to have_received(:payload_send)
  end
end
