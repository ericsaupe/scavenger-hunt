# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Avatars" do
  include ActiveSupport::Testing::TimeHelpers

  let(:hunt) { create(:hunt) }
  let(:team) { create(:team, hunt:, name: "owls") }
  let(:dicebear) { AvatarHelpers::DICEBEAR }

  it "fetches a team's critter from DiceBear once, keeps it and serves it as immutable SVG" do
    get team.avatar_url

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/svg+xml")
    expect(response.headers["Cache-Control"]).to eq("max-age=31536000, public, immutable")
    expect(response.headers["Content-Security-Policy"]).to eq("script-src 'none'")
    expect(response.headers["Set-Cookie"]).to be_nil
    expect(response.body).to include("<animate ")
    expect(a_request(:get, %r{critters/svg}).with(query: hash_including("seed" => Avatar.digest("team", team.avatar_seed)))).to have_been_made.once

    get team.avatar_url
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("<animate ")
    expect(a_request(:get, dicebear)).to have_been_made.once
    expect(Avatar.where(kind: "team").count).to eq(1)
  end

  it "uses the thumbs style for people" do
    message = create(:message, hunt:)

    get message.avatar_url

    expect(response).to have_http_status(:ok)
    expect(a_request(:get, %r{thumbs/svg}).with(query: hash_including("seed" => Avatar.digest("person", message.sender_token)))).to have_been_made.once
  end

  it "serves a still variant with the animations stripped" do
    get team.avatar_url(still: true)

    expect(response).to have_http_status(:ok)
    expect(response.headers["Cache-Control"]).to eq("max-age=31536000, public, immutable")
    expect(response.body).not_to include("<animate")
    expect(response.body).not_to include("@keyframes")
    expect(response.body).not_to include("animation")
    expect(response.body).to include('class="eyes"')
    expect(response.body).to include("prefers-reduced-motion")
    expect(a_request(:get, dicebear)).to have_been_made.once
  end

  it "falls back to a marigold initial when DiceBear fails, without keeping the failure" do
    stub_dicebear(status: 503, body: "busy", content_type: "text/plain")

    get team.avatar_url

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/svg+xml")
    expect(response.headers["Cache-Control"]).to eq("max-age=60, public")
    expect(response.body).to include('fill="#ffb703"')
    expect(response.body).to include(">O</text>")
    expect(Avatar.count).to eq(0)
  end

  it "falls back when DiceBear times out or answers with something other than SVG" do
    stub_request(:get, dicebear).to_timeout
    get team.avatar_url
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(">O</text>")

    stub_dicebear(body: "<html><body>nope</body></html>", content_type: "text/html")
    get team.avatar_url
    expect(response.body).to include(">O</text>")

    stub_dicebear(body: "<svg xmlns='http://www.w3.org/2000/svg'><script>alert(1)</script></svg>")
    get team.avatar_url
    expect(response.body).to include(">O</text>")
    expect(Avatar.count).to eq(0)
  end

  it "shows a neutral face for people when DiceBear is down" do
    stub_dicebear(status: 500, body: "")

    get create(:message, hunt:).avatar_url

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('cx="36" cy="42"')
    expect(response.body).not_to include("<text")
  end

  it "waits a minute before asking DiceBear again after a failure" do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    stub_dicebear(status: 502, body: "")

    get team.avatar_url
    get team.avatar_url
    expect(a_request(:get, dicebear)).to have_been_made.once

    stub_dicebear
    get team.avatar_url
    expect(response.body).to include(">O</text>")
    expect(a_request(:get, dicebear)).to have_been_made.once

    travel 61.seconds do
      get team.avatar_url
    end
    expect(response.body).to include("<animate ")
    expect(a_request(:get, dicebear)).to have_been_made.twice
  end

  it "only answers for known kinds and well-formed digests" do
    get "/avatars/cat/#{"a" * 64}.svg"
    expect(response).to have_http_status(:not_found)

    get "/avatars/team/not-a-digest.svg"
    expect(response).to have_http_status(:not_found)
    expect(a_request(:get, dicebear)).not_to have_been_made
  end
end
