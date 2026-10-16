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
end
