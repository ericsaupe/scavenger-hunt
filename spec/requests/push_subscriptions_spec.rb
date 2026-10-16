# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Push subscriptions" do
  let(:hunt) { create(:hunt) }
  let(:path) { "/scavenger_hunts/#{hunt.code}/push_subscription" }
  let(:subscription) { {endpoint: "https://fcm.googleapis.com/fcm/send/abc", keys: {p256dh: "p256dh-key", auth: "auth-key"}} }

  before { cookies[:user_id] = "phone-1" }

  describe "POST" do
    it "stores the phone's subscription for this hunt under its user id" do
      post path, params: {subscription:}, as: :json, headers: {"User-Agent" => "Mozilla/5.0 (Android)"}

      expect(response).to have_http_status(:no_content)
      stored = hunt.push_subscriptions.sole
      expect(stored).to have_attributes(user_id: "phone-1", endpoint: "https://fcm.googleapis.com/fcm/send/abc",
        p256dh: "p256dh-key", auth: "auth-key", user_agent: "Mozilla/5.0 (Android)")
      expect(stored).to have_attributes(notify_starting_soon: true, notify_results: true, notify_show: true, notify_lead_change: true)
    end

    it "replaces the keys when the same phone subscribes again" do
      post path, params: {subscription:}, as: :json
      post path, params: {subscription: subscription.merge(endpoint: "https://fcm.googleapis.com/fcm/send/new")}, as: :json

      expect(hunt.push_subscriptions.count).to eq(1)
      expect(hunt.push_subscriptions.sole.endpoint).to eq("https://fcm.googleapis.com/fcm/send/new")
    end

    it "keeps subscriptions to other hunts apart" do
      other = create(:hunt)
      post path, params: {subscription:}, as: :json
      post "/scavenger_hunts/#{other.code}/push_subscription", params: {subscription:}, as: :json

      expect(PushSubscription.where(user_id: "phone-1").pluck(:hunt_id)).to contain_exactly(hunt.id, other.id)
    end

    it "refuses a subscription without keys" do
      post path, params: {subscription: {endpoint: "https://fcm.googleapis.com/fcm/send/abc"}}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(hunt.push_subscriptions).to be_empty
    end
  end

  describe "PATCH" do
    it "updates this phone's preferences for the hunt" do
      stored = create(:push_subscription, hunt:, user_id: "phone-1")
      create(:push_subscription, hunt:, user_id: "phone-2")

      patch path, params: {push_subscription: {notify_lead_change: false}}, as: :json

      expect(response).to have_http_status(:no_content)
      expect(stored.reload).to have_attributes(notify_lead_change: false, notify_results: true)
      expect(hunt.push_subscriptions.find_by(user_id: "phone-2").notify_lead_change).to be(true)
    end

    it "ignores anything but the preferences" do
      stored = create(:push_subscription, hunt:, user_id: "phone-1")

      patch path, params: {push_subscription: {user_id: "someone-else", endpoint: "https://evil.example.com"}}, as: :json

      expect(stored.reload).to have_attributes(user_id: "phone-1", endpoint: stored.endpoint)
    end

    it "is not found for a phone that never subscribed" do
      patch path, params: {push_subscription: {notify_lead_change: false}}, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE" do
    it "forgets this phone's subscription for the hunt and nobody else's" do
      mine = create(:push_subscription, hunt:, user_id: "phone-1")
      theirs = create(:push_subscription, hunt:, user_id: "phone-2")
      elsewhere = create(:push_subscription, user_id: "phone-1")

      delete path, as: :json

      expect(response).to have_http_status(:no_content)
      expect(PushSubscription.exists?(mine.id)).to be(false)
      expect(PushSubscription.exists?(theirs.id)).to be(true)
      expect(PushSubscription.exists?(elsewhere.id)).to be(true)
    end
  end

  describe "the hunt page" do
    it "offers notifications and the settings list only when VAPID keys are configured" do
      get "/scavenger_hunts/#{hunt.code}"
      expect(response.body).to include('data-testid="push-prompt"')
      expect(response.body).to include('data-testid="notification-settings"')
      expect(response.body).to include(PushSubscription.vapid[:public_key])

      allow(PushSubscription).to receive(:configured?).and_return(false)
      get "/scavenger_hunts/#{hunt.code}"
      expect(response.body).not_to include('data-testid="push-prompt"')
      expect(response.body).not_to include('data-testid="notification-settings"')
    end

    it "renders this phone's preferences into the settings list" do
      create(:push_subscription, hunt:, user_id: "phone-1", notify_show: false)

      get "/scavenger_hunts/#{hunt.code}"

      expect(response.body).to include('data-push-settings-subscribed-value="true"')
      expect(response.body).to match(/name="notify_results"[^>]*checked/)
      expect(response.body).not_to match(/name="notify_show"[^>]*checked/)
    end
  end
end
