# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Banners" do
  it "returns a banner with the message" do
    get "/banner?message=Hello%20World"
    expect(response.body).to include("Hello World")
  end

  it "escapes the message" do
    get '/banner?message=<script>alert("Hello World")</script>'
    expect(response.body).to include("&lt;script&gt;alert(&quot;Hello World&quot;)&lt;/script&gt;")
  end
end
