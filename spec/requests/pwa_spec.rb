# frozen_string_literal: true

require "rails_helper"

RSpec.describe "PWA" do
  describe "the manifest" do
    it "describes an installable app that opens on the join page" do
      get "/manifest.json"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")

      manifest = response.parsed_body
      expect(manifest["name"]).to eq("Scavenger Hunt Party")
      expect(manifest["short_name"]).to be_present
      expect(manifest["display"]).to eq("standalone")
      expect(manifest["start_url"]).to eq("/scavenger_hunts/join")
      expect(manifest["theme_color"]).to match(/\A#\h{6}\z/)
      expect(manifest["background_color"]).to match(/\A#\h{6}\z/)
      expect(manifest["icons"].pluck("sizes")).to include("192x192", "512x512")
      expect(manifest["icons"].pluck("src")).to all(satisfy { |src| Rails.public_path.join(src.delete_prefix("/")).exist? })
    end

    it "is linked from the layout" do
      get "/"

      expect(response.body).to include('<link rel="manifest" href="/manifest.json">')
    end
  end

  describe "the service worker" do
    it "precaches the digested assets, the icons and the offline page" do
      get "/service-worker.js"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/javascript")
      precache = response.body[/const PRECACHE = (\[.*?\])/m, 1]
      expect(JSON.parse(precache)).to include(
        a_string_matching(%r{\A/assets/application-\h+\.css\z}),
        a_string_matching(%r{\A/assets/application-\h+\.js\z}),
        "/offline",
        "/android-chrome-192x192.png",
        "/android-chrome-512x512.png"
      )
    end

    it "serves the offline page" do
      get "/offline"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("You're offline")
    end
  end
end
