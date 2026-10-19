# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubmissionsReopenedJob do
  include ActiveSupport::Testing::TimeHelpers

  let(:hunt) { create(:hunt, name: "Halloween Haunt Hunt", ends_at: 30.minutes.ago) }

  before { freeze_time }

  it "tells every other phone that wants announcements how long it has" do
    create(:push_subscription, hunt:, user_id: "phone-1")
    create(:push_subscription, hunt:, user_id: "phone-2", notify_announcements: false)
    create(:push_subscription, hunt:, user_id: "organizer")
    hunt.update!(reopened_at: Time.current, ends_at: 10.minutes.from_now)

    described_class.perform_now(hunt, "organizer")

    expect(WebPush).to have_received(:payload_send).once
    expect(pushed_messages.first).to include(
      "title" => "Submissions are open again",
      "body" => "You have 10 minutes to add photos that didn't make it in to Halloween Haunt Hunt.",
      "url" => "/my_hunt?hunt=#{hunt.code}"
    )
  end

  it "rounds the time left up to whole minutes" do
    create(:push_subscription, hunt:)
    hunt.update!(reopened_at: 1.minute.ago, ends_at: 30.seconds.from_now)

    described_class.perform_now(hunt, nil)

    expect(pushed_messages.first["body"]).to start_with("You have 1 minute to add photos")
  end

  it "stays quiet for a hunt that was never reopened or has closed again" do
    create(:push_subscription, hunt:)

    described_class.perform_now(hunt, nil)
    hunt.update!(reopened_at: 20.minutes.ago, ends_at: 5.minutes.ago)
    described_class.perform_now(hunt, nil)

    expect(WebPush).not_to have_received(:payload_send)
  end
end
