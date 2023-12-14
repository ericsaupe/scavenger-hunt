# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Presenter" do
  let(:hunt) { create(:hunt) }
  let(:team) { create(:team, hunt:) }

  describe "presenter page" do
    before do
      allow(ActiveStorage::Current).to receive(:url_options).and_return(host: "localhost:3000")
      create(:video_submission, item: hunt.items.first, team:)
      create(:photo_submission, item: hunt.items.second, team:)
    end

    context "as hunt owner" do
      it "displays presenter controls" do
        allow_any_instance_of(Hunt).to receive(:owner?).and_return(true)
        visit "/scavenger_hunts/#{hunt.code}/presenter"
        expect(page).to have_content("«")
        expect(page).to have_content("»")
      end
    end

    context "not as hunt owner" do
      it "does not display presenter controls" do
        visit "/scavenger_hunts/#{hunt.code}/presenter"
        expect(page).not_to have_content("«")
        expect(page).not_to have_content("»")
      end
    end
  end
end
