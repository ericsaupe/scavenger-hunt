# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Presenter" do
  let(:hunt) { create(:hunt) }
  let(:team) { create(:team, hunt:) }

  describe "presenter page" do
    before do
      allow(ActiveStorage::Current).to receive(:url_options).and_return(host: "localhost:3000")
      @video_submission = create(:video_submission, item: hunt.items.first, team:)
      @photo_submission = create(:photo_submission, item: hunt.items.second, team:)
    end

    context "as hunt owner" do
      before do
        allow_any_instance_of(Hunt).to receive(:owner?).and_return(true)
      end

      it "displays presenter controls" do
        visit "/scavenger_hunts/#{hunt.code}/presenter"
        expect(page).to have_content("«")
        expect(page).to have_content("»")
      end

      it "saves the current submission id" do
        expect_any_instance_of(Hunt).to receive(:update).with(presentation_submission: @video_submission)
        visit "/scavenger_hunts/#{@video_submission.hunt.code}/presenter?submission_id=#{@video_submission.id}"
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

      it "does not save or transmit" do
        expect_any_instance_of(Hunt).not_to receive(:update).with(presentation_submission: @video_submission)
        expect_any_instance_of(Hunt).not_to receive(:broadcast_presentation_update)
        visit "/scavenger_hunts/#{@video_submission.hunt.code}/presenter?submission_id=#{@video_submission.id}"
        expect(page).not_to have_content("«")
        expect(page).not_to have_content("»")
      end
    end
  end
end
