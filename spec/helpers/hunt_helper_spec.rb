require "rails_helper"

RSpec.describe HuntHelper do
  describe "#hunt_qr_code_svg" do
    let(:hunt) { create(:hunt) }

    it "renders an html safe svg of the hunt url" do
      svg = helper.hunt_qr_code_svg(hunt)
      expected = RQRCode::QRCode.new(helper.hunt_url(hunt.code.upcase)).as_svg(fill: "fff", viewbox: true)

      expect(svg).to be_html_safe
      expect(svg.to_str).to eq(expected)
    end
  end

  describe "#checklist_folds" do
    let(:team) { create(:team) }

    it "reads the sections this phone folded or unfolded for the team" do
      helper.request.cookies["checklist_#{team.id}"] = '{"12":"closed","15":"open"}'

      expect(helper.checklist_folds(team)).to eq("12" => "closed", "15" => "open")
    end

    it "treats a missing cookie as no choices made" do
      expect(helper.checklist_folds(team)).to eq({})
    end

    ["not json", "[12]", "null"].each do |value|
      it "ignores a cookie holding #{value}" do
        helper.request.cookies["checklist_#{team.id}"] = value

        expect(helper.checklist_folds(team)).to eq({})
      end
    end
  end

  describe "#found_count" do
    it "counts what has been found out of the section" do
      expect(helper.found_count(4, 10)).to eq("4 of 10 found")
      expect(helper.found_count(0, 0)).to eq("0 of 0 found")
    end

    it "says when everything has been found" do
      expect(helper.found_count(6, 6)).to eq("All 6 found")
    end
  end
end
