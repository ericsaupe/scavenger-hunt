# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Results" do
  context "with a hunt started" do
    let(:hunt) { create(:hunt) }
    let(:team) { create(:team, hunt:) }
    let(:photo_submission) { create(:photo_submission, item: hunt.items.second, team:) }

    describe "voting" do
      before do
        allow(ActiveStorage::Current).to receive(:url_options).and_return(host: "localhost:3000")
      end

      it "records a vote" do
        visit "scavenger_hunts/#{hunt.code}/items/#{photo_submission.item_id}"
        find("[data-testid='vote-menu-button']").click
        find("[data-testid='vote-menu-love-button']").click
        expect(page).to have_selector("[data-vote-value-value='love']")
        expect(Vote.count).to eq(1)
        expect(Vote.last).to be_loved
      end

      it "displays maximum downvotes" do
        hunt.update!(max_downvotes_to_lose_points: 1)
        visit "scavenger_hunts/#{hunt.code}/items/#{photo_submission.item_id}"
        expect(page).to have_text("0 / 1")
      end

      it "unrecords a vote if it is the same" do
        visit "scavenger_hunts/#{hunt.code}/items/#{photo_submission.item_id}"
        find("[data-testid='vote-menu-button']").click
        find("[data-testid='vote-menu-love-button']").click
        # First click
        expect(page).to have_selector("[data-vote-value-value='love']")
        expect(Vote.count).to eq(1)
        expect(Vote.last).to be_loved
        # Second click
        find("[data-testid='vote-menu-button']").click
        find("[data-testid='vote-menu-love-button']").click
        expect(page).to have_selector("[data-vote-value-value='']")
        expect(Vote.count).to eq(1)
        expect(Vote.last).not_to be_loved
      end

      it "changes a vote" do
        visit "scavenger_hunts/#{hunt.code}/items/#{photo_submission.item_id}"
        find("[data-testid='vote-menu-button']").click
        find("[data-testid='vote-menu-love-button']").click
        # First click
        expect(page).to have_selector("[data-vote-value-value='love']")
        expect(Vote.count).to eq(1)
        expect(Vote.last).to be_loved
        # Second click
        find("[data-testid='vote-menu-button']").click
        find("[data-testid='vote-menu-deny-button']").click
        expect(page).to have_selector("[data-vote-value-value='deny']")
        expect(Vote.count).to eq(1)
        expect(Vote.last).to be_denied
      end

      it "changes the vote with the current result" do
        second_submission = create(:photo_submission, item: hunt.items.second, team: create(:team, hunt: hunt))
        visit "scavenger_hunts/#{hunt.code}/items/#{photo_submission.item_id}"
        # First click
        page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
        find("a[href='#submission_#{photo_submission.id}']").click
        sleep(1)
        within("[data-vote-submission-id-value='#{photo_submission.id}']") do
          find("[data-testid='vote-menu-button']").click
          find("[data-testid='vote-menu-love-button']").click
          sleep(1)
          expect(Vote.count).to eq(1)
          expect(Vote.last).to be_loved
        end
        # Second click
        page.execute_script("window.scrollTo(0, 0)") # Bug in Chrome with carousel @see https://github.com/saadeghi/daisyui/issues/2442
        find("a[href='#submission_#{second_submission.id}']").click
        sleep(1)
        within("[data-vote-submission-id-value='#{second_submission.id}']") do
          find("[data-testid='vote-menu-button']").click
          find("[data-testid='vote-menu-love-button']").click
          sleep(1)
          expect(Vote.count).to eq(2)
          expect(Vote.last).to be_loved
        end
      end

      it "hides downvote if downvotes are not enabled" do
        hunt.update(max_downvotes_to_lose_points: nil)
        visit "scavenger_hunts/#{hunt.code}/items/#{photo_submission.item_id}"
        find("[data-testid='vote-menu-button']").click
        expect(page).not_to have_selector("[data-testid='vote-menu-deny-button']")
      end
    end
  end
end
