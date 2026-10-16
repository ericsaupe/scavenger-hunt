# frozen_string_literal: true

require "rails_helper"

RSpec.describe ShowStartingJob do
  let(:hunt) { create(:hunt) }

  it "invites phones to watch along" do
    create(:push_subscription, hunt:)
    create(:push_subscription, hunt:, notify_show: false)

    described_class.perform_now(hunt)

    expect(WebPush).to have_received(:payload_send).once
    expect(pushed_messages.first).to include("title" => "The show is starting", "url" => "/scavenger_hunts/#{hunt.code}/presenter")
  end

  it "forgets a phone the push service no longer knows" do
    gone = create(:push_subscription, hunt:)
    allow(WebPush).to receive(:payload_send).and_raise(push_response_error(WebPush::InvalidSubscription, 404))

    described_class.perform_now(hunt)

    expect(PushSubscription.exists?(gone.id)).to be(false)
  end
end
