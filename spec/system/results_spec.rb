# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Results" do
  context "with a hunt started" do
    let(:hunt) { create(:hunt) }
    let(:team) { video_submission.team }
    let(:video_submission) { create(:video_submission, item: hunt.items.first) }
    let(:photo_submission) { create(:photo_submission, item: hunt.items.second, team:) }

    describe "results page" do
      it "displays the results" do
        visit "/scavenger_hunts/#{hunt.code}/results"
        expect(page).not_to have_content("Results are not yet available!")
        expect(page).to have_content(hunt.name.upcase)
        expect(page).to have_content(team.score)
      end

      it "downloads the results" do
        expect(hunt.archive.attached?).to be(false)
        visit "/scavenger_hunts/#{hunt.code}/results"
        expect(page).to have_content("Download")
        expect { click_on("Download") }.not_to raise_error
      end

      context "locked by time" do
        before do
          hunt.update(ends_at: 1.year.from_now, lock_results: true)
        end

        it "does not display the results" do
          visit "/scavenger_hunts/#{hunt.code}/results"
          expect(page).to have_content("Results are not yet available!")
        end
      end

      context "locked with password" do
        before do
          hunt.update(lock_password: "hunter2")
        end

        it "does not display the results" do
          visit "/scavenger_hunts/#{hunt.code}/results"
          expect(page).to have_content("Results are not yet available!")
        end

        it "displays results after entering password" do
          visit "/scavenger_hunts/#{hunt.code}/results"
          expect(page).to have_content("Results are not yet available!")
          fill_in "Password", with: "hunter2"
          click_on "Unlock Results!"
          expect(page).not_to have_content("Results are not yet available!")
          expect(page).to have_content(hunt.name.upcase)
          expect(page).to have_content(team.score)
        end
      end
    end

    describe "single result page" do
      it "displays the video submission" do
        visit "scavenger_hunts/#{hunt.code}/items/#{video_submission.item_id}"
        expect(page).to have_content(team.name)
      end

      it "displays the photo submission" do
        allow(ActiveStorage::Current).to receive(:url_options).and_return(host: "localhost:3000")
        visit "scavenger_hunts/#{hunt.code}/items/#{photo_submission.item_id}"
        expect(page).to have_content(team.name)
      end
    end

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
    end
  end
end
