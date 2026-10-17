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

    it "offers Join a hunt and My hunt shortcuts with maskable icons" do
      get "/manifest.json"

      shortcuts = response.parsed_body["shortcuts"]
      expect(shortcuts.pluck("name", "url")).to eq([["Join a hunt", "/scavenger_hunts/join"], ["My hunt", "/my_hunt"]])
      shortcuts.each do |shortcut|
        icon = shortcut["icons"].sole
        expect(icon).to include("sizes" => "96x96", "type" => "image/png", "purpose" => "maskable")
        image = Vips::Image.new_from_file(Rails.public_path.join(icon["src"].delete_prefix("/")).to_s)
        expect([image.width, image.height]).to eq([96, 96])
      end
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

    it "caches avatars offline once seen, but never a fallback, and leaves the precache list alone" do
      get "/service-worker.js"

      expect(response.body).to include('avatars: "avatars-v1"')
      expect(response.body).to include('url.pathname.startsWith("/avatars/")')
      expect(response.body).to include("cacheFirst(request, CACHES.avatars, immutable)")
      expect(response.body).to include('includes("immutable")')
      expect(JSON.parse(response.body[/const PRECACHE = (\[.*?\])/m, 1])).not_to include(a_string_matching(%r{/avatars/}))
    end

    it "shows pushes as notifications that open their url" do
      get "/service-worker.js"

      expect(response.body).to include('addEventListener("push"')
      expect(response.body).to include("showNotification(")
      expect(response.body).to include('addEventListener("notificationclick"')
      expect(response.body).to include("clients.openWindow(")
      expect(response.body).to include("/android-chrome-192x192.png")
    end

    it "serves the offline page" do
      get "/offline"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("You're offline")
    end
  end
end
