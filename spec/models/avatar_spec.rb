# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avatar do
  describe ".for" do
    it "builds a stable URL from an HMAC of the seed, so the seed never appears in it" do
      url = Avatar.for(:person, "secret token")

      expect(url).to match(%r{\A/avatars/person/\h{64}\.svg\z})
      expect(url).not_to include("secret")
      expect(Avatar.for(:person, "secret token")).to eq(url)
      expect(Avatar.for(:team, "secret token")).not_to eq(url)
      expect(Avatar.for(:person, "other token")).not_to eq(url)
    end

    it "signs the digest so only URLs the app produced are ever fetched" do
      digest = Avatar.digest("person", "token")

      expect(Avatar.valid_digest?("person", digest)).to be(true)
      expect(Avatar.valid_digest?("team", digest)).to be(false)
      expect(Avatar.valid_digest?("person", digest.reverse)).to be(false)
      expect(Avatar.valid_digest?("person", nil)).to be(false)
    end

    it "adds a single upcased initial for the fallback" do
      expect(Avatar.for(:team, "seed", initial: "owls")).to end_with(".svg?initial=O")
      expect(Avatar.for(:team, "seed", initial: "")).to end_with(".svg")
    end

    it "only knows teams and people" do
      expect { Avatar.for(:cat, "seed") }.to raise_error(ArgumentError)
    end
  end

  describe ".dicebear_uri" do
    it "asks for the animated variant, since DiceBear returns a still avatar by default" do
      expect(Avatar.dicebear_uri("team", "abc").to_s).to eq("https://api.dicebear.com/10.x/critters/svg?seed=abc&animationVariant=medium")
      expect(Avatar.dicebear_uri("person", "abc").to_s).to eq("https://api.dicebear.com/10.x/thumbs/svg?seed=abc&animationVariant=medium")
    end
  end

  describe ".fetch" do
    it "returns the row another request stored first instead of failing on the unique index" do
      digest = Avatar.digest("team", "seed")
      winner = Avatar.create!(kind: "team", digest:, svg: "<svg xmlns='http://www.w3.org/2000/svg'/>")

      expect(Avatar.fetch("team", digest)).to eq(winner)
      expect(Avatar.count).to eq(1)
      expect(a_request(:get, AvatarHelpers::DICEBEAR)).to have_been_made.once
    end
  end

  describe ".desynchronize" do
    it "scopes a per-avatar speed and negative delay to the SVG's own id, and leaves other SVGs alone" do
      svg = Rails.root.join("spec/fixtures/avatar.svg").read
      digest = "ab" * 32

      personal = Avatar.desynchronize(svg, digest)

      expect(personal).to start_with(%(<svg id="avababababab"))
      expect(personal).to end_with(%(<style>#avababababab{--dbcr-t:#{Avatar.timing(digest)[:speed]}}#avababababab [class*='dbcr-']{animation-delay:-#{Avatar.timing(digest)[:delay]}s}</style></svg>))
      expect(Avatar.desynchronize("<svg xmlns='http://www.w3.org/2000/svg'><circle r='1'/></svg>", digest)).to eq("<svg xmlns='http://www.w3.org/2000/svg'><circle r='1'/></svg>")
    end
  end
end
