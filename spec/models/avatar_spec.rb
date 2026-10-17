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

    it "adds the still flag and a single upcased initial for the fallback" do
      expect(Avatar.for(:team, "seed", initial: "owls")).to end_with(".svg?initial=O")
      expect(Avatar.for(:team, "seed", initial: "owls", still: true)).to end_with(".svg?initial=O&still=1")
      expect(Avatar.for(:person, "seed", still: true)).to end_with(".svg?still=1")
    end

    it "only knows teams and people" do
      expect { Avatar.for(:cat, "seed") }.to raise_error(ArgumentError)
    end
  end

  describe ".dicebear_uri" do
    it "asks for the style's animated variants, one parameter each, since DiceBear rejects comma lists" do
      expect(Avatar.dicebear_uri("team", "abc").to_s).to eq("https://api.dicebear.com/10.x/critters/svg?seed=abc&animationVariant=fast&animationVariant=medium&animationVariant=slow")
      expect(Avatar.dicebear_uri("person", "abc").to_s).to start_with("https://api.dicebear.com/10.x/thumbs/svg?seed=abc&")
    end
  end

  describe "#still_svg" do
    it "removes SMIL and CSS animations but keeps the drawing" do
      avatar = Avatar.new(kind: "team", digest: "a" * 64, svg: Rails.root.join("spec/fixtures/avatar.svg").read)

      still = avatar.still_svg

      expect(still).not_to include("<animate")
      expect(still).not_to include("@keyframes")
      expect(still).not_to include("animation")
      expect(still).to include("<circle")
      expect(still).to include("transform-box:fill-box")
      expect(Nokogiri::XML(still) { |config| config.strict }.root.name).to eq("svg")
    end
  end
end
