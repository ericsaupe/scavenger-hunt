# frozen_string_literal: true

require "rails_helper"

RSpec.describe PushSubscription do
  it { is_expected.to belong_to(:hunt) }
  it { is_expected.to validate_presence_of(:user_id) }
  it { is_expected.to validate_presence_of(:p256dh) }
  it { is_expected.to validate_presence_of(:auth) }

  it "only accepts https endpoints" do
    subscription = build(:push_subscription, endpoint: "http://fcm.googleapis.com/fcm/send/1")

    expect(subscription).not_to be_valid
    expect(subscription.errors[:endpoint]).to be_present
  end

  it "only talks to the browsers' own push services" do
    %w[https://fcm.googleapis.com/fcm/send/x https://updates.push.services.mozilla.com/wpush/v2/x
      https://web.push.apple.com/x https://wns2-bn1p.notify.windows.com/w/x].each do |endpoint|
      expect(build(:push_subscription, endpoint:)).to be_valid
    end

    %w[https://10.0.0.5/metrics https://localhost:3000/admin https://fcm.googleapis.com.evil.example/x https://evilfcm.googleapis.com/x not-a-url].each do |endpoint|
      subscription = build(:push_subscription, endpoint:)
      expect(subscription).not_to be_valid, endpoint
      expect(subscription.errors[:endpoint]).to be_present
    end
  end

  it "wants every kind of notification by default" do
    subscription = create(:push_subscription)

    expect(described_class::PREFERENCES.map { |preference| subscription.public_send(preference) }).to all(be(true))
  end

  it "allows one subscription per phone and hunt" do
    existing = create(:push_subscription)

    expect { create(:push_subscription, hunt: existing.hunt, user_id: existing.user_id) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  describe ".for_event" do
    it "leaves out phones that turned that event off" do
      wants = create(:push_subscription)
      create(:push_subscription, hunt: wants.hunt, notify_lead_change: false)

      expect(described_class.for_event(:lead_change)).to eq([wants])
    end
  end

  describe "#deliver" do
    let(:subscription) { create(:push_subscription) }

    it "sends a signed payload with the title, body, url and icon" do
      expect(subscription.deliver(title: "Hi", body: "There", url: "/scavenger_hunts/ABCDE", tag: "show-1")).to be(true)

      expect(WebPush).to have_received(:payload_send).with(
        hash_including(endpoint: subscription.endpoint, p256dh: subscription.p256dh, auth: subscription.auth,
          vapid: hash_including(:public_key, :private_key, :subject), urgency: "high", open_timeout: 10, read_timeout: 10)
      )
      expect(pushed_messages.first).to eq("title" => "Hi", "body" => "There", "url" => "/scavenger_hunts/ABCDE", "tag" => "show-1", "icon" => "/android-chrome-192x192.png")
    end

    it "deletes itself when the push service says the subscription is gone" do
      allow(WebPush).to receive(:payload_send).and_raise(push_response_error(WebPush::ExpiredSubscription, 410))

      expect(subscription.deliver(title: "Hi", body: "There", url: "/")).to be(false)
      expect(described_class.exists?(subscription.id)).to be(false)
    end

    it "deletes itself when the push service does not know the subscription" do
      allow(WebPush).to receive(:payload_send).and_raise(push_response_error(WebPush::InvalidSubscription, 404))

      subscription.deliver(title: "Hi", body: "There", url: "/")

      expect(described_class.exists?(subscription.id)).to be(false)
    end

    it "keeps the subscription and reports any other push service error" do
      allow(WebPush).to receive(:payload_send).and_raise(push_response_error(WebPush::PushServiceError, 500))
      allow(Rails.error).to receive(:report)

      expect(subscription.deliver(title: "Hi", body: "There", url: "/")).to be(false)
      expect(described_class.exists?(subscription.id)).to be(true)
      expect(Rails.error).to have_received(:report).with(instance_of(WebPush::PushServiceError), handled: true)
    end
  end
end
