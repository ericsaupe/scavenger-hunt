# frozen_string_literal: true

require "rails_helper"

RSpec.describe AnnouncementJob do
  let(:hunt) { create(:hunt, owner_id: "organizer") }
  let!(:message) { create(:message, hunt:, user_id: "organizer", organizer: true, announcement: true, content: "Pizza at 7 by the gazebo") }

  it "tells every other phone that wants announcements" do
    create(:push_subscription, hunt:, user_id: "phone-1")
    create(:push_subscription, hunt:, user_id: "phone-2", notify_announcements: false)
    create(:push_subscription, hunt:, user_id: "organizer")

    described_class.perform_now(message)

    expect(WebPush).to have_received(:payload_send).once
    expect(pushed_messages.first).to include("title" => "From the organizer", "body" => "Pizza at 7 by the gazebo", "url" => "/my_hunt?hunt=#{hunt.code}", "tag" => "announcements-#{hunt.id}")
  end

  it "stays quiet for ordinary messages, plain organizer messages and removed announcements" do
    create(:push_subscription, hunt:, user_id: "phone-1")

    described_class.perform_now(create(:message, hunt:))
    described_class.perform_now(create(:message, hunt:, user_id: "organizer", organizer: true))
    message.remove!
    described_class.perform_now(message)

    expect(WebPush).not_to have_received(:payload_send)
  end
end
