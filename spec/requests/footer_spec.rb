# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Footer" do
  let(:hunt) { create(:hunt) }

  def footer
    Nokogiri::HTML(response.body).at_css("[data-testid='footer']")
  end

  it "credits the author, the licence and the repository on the home, list and results pages" do
    ["/", "/scavenger_hunts", "/scavenger_hunts/#{hunt.code}/results"].each do |path|
      get path

      expect(response).to have_http_status(:ok)
      expect(footer).to be_present, "expected a footer on #{path}"
      expect(footer.text).to include("Made by Eric Saupe")
      expect(footer.text).to include("free software under the GPL-3.0")
      expect(footer.at_css("a[href='https://github.com/ericsaupe/scavenger-hunt']").text).to eq("Scavenger Hunt Party")
      expect(footer.at_css("a[href='https://github.com/ericsaupe/scavenger-hunt/blob/main/COPYING']").text).to eq("GPL-3.0")
      expect(footer.at_css("a[href='https://github.com/ericsaupe/scavenger-hunt/issues']").text).to eq("Report a problem")
      footer.css("a").each do |link|
        expect(link["target"]).to eq("_blank")
        expect(link["rel"]).to eq("noopener")
      end
    end
  end

  it "keeps the DiceBear credit on the results page only" do
    get "/scavenger_hunts/#{hunt.code}/results"
    expect(footer.at_css("[data-testid='avatar-credit']").text).to include("DiceBear")

    get "/"
    expect(footer.at_css("[data-testid='avatar-credit']")).to be_nil
  end

  it "stays off the pages teams and presenters work on" do
    team = create(:team, hunt:)
    team.submissions.first.photo.attach(io: Rails.root.join("spec/fixtures/test.jpg").open, filename: "test.jpg")

    ["/scavenger_hunts/#{hunt.code}", "/scavenger_hunts/#{hunt.code}/teams/#{team.id}", "/scavenger_hunts/#{hunt.code}/presenter?screen=big"].each do |path|
      get path

      expect(response).to have_http_status(:ok)
      expect(footer).to be_nil, "expected no footer on #{path}"
    end
  end
end
