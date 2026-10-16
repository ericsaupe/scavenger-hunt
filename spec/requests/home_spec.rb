# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Home" do
  it "renders without reading the cache" do
    reads = []
    subscriber = ->(*, payload) { reads << payload[:key] }
    ActiveSupport::Notifications.subscribed(subscriber, "cache_read.active_support") { get "/" }

    expect(response).to have_http_status(:ok)
    expect(reads).to be_empty
  end
end
