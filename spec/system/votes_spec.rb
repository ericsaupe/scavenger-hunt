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
        find("[data-testid='vote-menu-love-button']").click
        expect(page).to have_selector("[data-vote-value-value='love']")
        expect(Vote.count).to eq(1)
        expect(Vote.last).to be_loved
      end

      it "displays the flag threshold" do
        hunt.update!(max_downvotes_to_lose_points: 3)
        visit "scavenger_hunts/#{hunt.code}/items/#{photo_submission.item_id}"
        expect(page).to have_css("[data-testid='flag-counter']", text: "0 of 3 flags")
        expect(page).to have_button("Flag it")
        expect(page).not_to have_css("[data-testid='vote-menu-deny-button']")
      end

      it "flags a photo and marks it when it stops counting" do
        hunt.update!(max_downvotes_to_lose_points: 2)
        create(:downvote, submission: photo_submission)
        visit "scavenger_hunts/#{hunt.code}/items/#{photo_submission.item_id}"
        expect(page).to have_css("[data-testid='flag-counter']", text: "1 of 2 flags")
        expect(page).not_to have_css("[data-testid='doesnt-count']")

        click_on "Flag it"
        expect(page).to have_button("Flagged")
        expect(page).to have_css("[data-testid='vote-menu-flag-button'][aria-pressed='true']")
        expect(page).to have_css("[data-testid='flag-counter']", text: "2 of 2 flags")
        expect(page).to have_css("[data-testid='doesnt-count']", text: /doesn't count/i)
        expect(photo_submission.reload).to be_denied_points

        click_on "Flagged"
        expect(page).to have_button("Flag it")
        expect(page).to have_css("[data-testid='vote-menu-flag-button'][aria-pressed='false']")
        expect(page).to have_css("[data-testid='flag-counter']", text: "1 of 2 flags")
        expect(page).not_to have_css("[data-testid='doesnt-count']")
        expect(photo_submission.reload).not_to be_denied_points
      end

      it "counts a double tap once" do
        visit "scavenger_hunts/#{hunt.code}/items/#{photo_submission.item_id}"
        find("[data-testid='vote-menu-love-button']").double_click
        expect(page).to have_selector("[data-vote-value-value='love']")
        sleep 1
        expect(page).to have_selector("[data-vote-value-value='love']")
        expect(Vote.count).to eq(1)
        expect(Vote.last).to be_loved
      end

      it "unrecords a vote if it is the same" do
        visit "scavenger_hunts/#{hunt.code}/items/#{photo_submission.item_id}"
        find("[data-testid='vote-menu-love-button']").click
        # First click
        expect(page).to have_selector("[data-vote-value-value='love']")
        expect(Vote.count).to eq(1)
        expect(Vote.last).to be_loved
        # Second click
        find("[data-testid='vote-menu-love-button']").click
        expect(page).to have_selector("[data-vote-value-value='']")
        expect(Vote.count).to eq(1)
        expect(Vote.last).not_to be_loved
      end

      it "changes a vote" do
        visit "scavenger_hunts/#{hunt.code}/items/#{photo_submission.item_id}"
        find("[data-testid='vote-menu-love-button']").click
        # First click
        expect(page).to have_selector("[data-vote-value-value='love']")
        expect(Vote.count).to eq(1)
        expect(Vote.last).to be_loved
        # Second click
        click_on "Flag it"
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
          find("[data-testid='vote-menu-love-button']").click
          sleep(1)
          expect(Vote.count).to eq(2)
          expect(Vote.last).to be_loved
        end
      end

      it "hides the flag if flags are not enabled" do
        hunt.update(max_downvotes_to_lose_points: nil)
        visit "scavenger_hunts/#{hunt.code}/items/#{photo_submission.item_id}"
        expect(page).not_to have_selector("[data-testid='vote-menu-flag-button']")
      end
    end
  end
end
