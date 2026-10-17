# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Hunts" do
  context "creating a hunt" do
    it "creates a new hunt" do
      visit "/"
      click_on "Start a hunt", match: :first
      expect(page).to have_current_path(hunts_path)
      first("[data-testid='template']").click
      fill_in("Hunt name", with: "My Fun Scavenger Hunt")
      find("input#hunt_starts_at", visible: false).execute_script("this.value = '2030-01-01 12:00'")
      find("input#hunt_ends_at", visible: false).execute_script("this.value = '2030-02-01 12:00'")
      click_on "Create hunt"
      expect(page).to have_text("My Fun Scavenger Hunt")
      expect(page).to have_text("Pick your team")
      expect(page).to have_text("Print list")
    end

    it "supports locking" do
      visit "/"
      click_on "Start a hunt", match: :first
      expect(page).to have_current_path(hunts_path)
      first("[data-testid='template']").click
      fill_in("Hunt name", with: "My Fun Scavenger Hunt")
      find("input#hunt_starts_at", visible: false).execute_script("this.value = '2030-01-01 12:00'")
      find("input#hunt_ends_at", visible: false).execute_script("this.value = '2030-02-01 12:00'")
      find("input#hunt_lock_results", visible: false).execute_script("this.checked = true")
      fill_in("Results password", with: "hunter2")
      click_on "Create hunt"
      expect(page).to have_text("My Fun Scavenger Hunt")
      expect(page).to have_text("Pick your team")
      expect(page).to have_text("Print list")
      hunt = Hunt.last
      expect(hunt.lock_results).to be_truthy
      expect(hunt.lock_password).to be_present
    end
  end

  context "with a hunt started" do
    let(:hunt) { create(:hunt) }
    let(:team) { create(:team, hunt:) }

    it "creates a team" do
      visit "/scavenger_hunts/#{hunt.code.upcase}"
      fill_in "Or start a new team", with: "Test"
      click_on "Join the hunt"
      expect(page).to have_text("Test")
      expect(page).to have_text("Tap an item to take a photo or a video up to 60 seconds.")
    end

    it "requires a name to start a team" do
      visit "/scavenger_hunts/#{hunt.code.upcase}"
      click_on "Join the hunt"
      expect(page).to have_text("Please select a team or enter a team name")
    end

    it "joins a team" do
      team_name = team.name
      visit "/scavenger_hunts/#{hunt.code.upcase}"
      choose(team_name)
      click_on "Join the hunt"
      expect(page).to have_text(team_name)
      expect(page).to have_text("Tap an item to take a photo or a video up to 60 seconds.")
    end

    it "crosses off an item" do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      attach_file(Rails.root.join("spec/fixtures/test.jpg")) do
        find(:label, text: hunt.items.first.name).click
      end
      expect(page).to have_css("li[data-found]")
    end

    it "supports video" do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      page.execute_script(%(Object.defineProperty(HTMLMediaElement.prototype, "duration", { get: () => 5 })))
      attach_file(Rails.root.join("spec/fixtures/video.mp4")) do
        find(:label, text: hunt.items.first.name).click
      end
      expect(page).to have_css("li[data-found]")
    end

    it "changes the image" do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      attach_file(Rails.root.join("spec/fixtures/test.jpg")) do
        find(:label, text: hunt.items.first.name).click
      end
      expect(page).to have_css("li[data-found]")

      find("[data-testid='preview']", text: hunt.items.first.name).click
      expect(page).to have_button("Retake")
      attach_file(Rails.root.join("spec/fixtures/test.jpg")) do
        find(:button, text: "Retake").click
      end
      expect(page).to have_css("li[data-found]")
    end

    it "closes the modal" do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      attach_file(Rails.root.join("spec/fixtures/test.jpg")) do
        find(:label, text: hunt.items.first.name).click
      end
      expect(page).to have_css("li[data-found]")

      find("[data-testid='preview']", text: hunt.items.first.name).click
      expect(page).to have_button("Done")
      click_on "Done"
      expect(page).not_to have_button("Done")
    end

    it "updates the score" do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      expect(page).to have_css("#team_#{team.id}", exact_text: "0")
      item = hunt.items.first
      points = item.category.points
      attach_file(Rails.root.join("spec/fixtures/test.jpg")) do
        find(:label, text: item.name).click
      end
      expect(page).to have_css("#team_#{team.id}", exact_text: points.to_s)
    end

    it "prints" do
      visit "/scavenger_hunts/#{hunt.code.upcase}/print"
      expect(page).to have_text("Code: #{hunt.code.upcase}")
      expect(page).to have_css(".qr-code")
    end

    it "prints a long list on one page" do
      27.times { |i| create(:item, category: hunt.categories.first, name: "Thing #{i + 1}") }
      visit "/scavenger_hunts/#{hunt.code.upcase}/print"
      expect(page).to have_css("li", count: 30)
      pdf = Base64.decode64(page.driver.browser.print_page)
      expect(pdf[%r{/Count (\d+)}, 1].to_i).to eq(1)
    end

    context "when remembering" do
      it "remembers past hunts" do
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        visit "/scavenger_hunts/join"
        click_on hunt.name
        expect(page).to have_text("Pick your team")

        second_hunt = create(:hunt)
        visit "/scavenger_hunts/#{second_hunt.code.upcase}"
        visit "/scavenger_hunts/join"
        click_on second_hunt.name
        expect(page).to have_text("Pick your team")
      end

      it "takes you straight back to your team's checklist" do
        visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        visit "/scavenger_hunts/join"
        click_on "#{team.name} - #{hunt.name}"
        expect(page).to have_current_path("/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}")
        expect(page).to have_text("Tap an item to take a photo or a video up to 60 seconds.")
      end
    end
  end

  context "timers" do
    let(:hunt) { create(:hunt) }
    let(:team) { create(:team, hunt:) }

    describe "when starting" do
      before do
        hunt.update(starts_at: 1.hour.from_now)
      end

      it "shows the timer" do
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        expect(page).to have_text("Starts in")
      end

      it "does not show the view results button" do
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        expect(page).not_to have_text("View results")
      end
    end

    describe "when in progress" do
      before do
        hunt.update(ends_at: 1.hour.from_now)
      end

      it "shows the timer" do
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        expect(page).to have_text("Ends in")
      end

      it "does not show the view results button" do
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        expect(page).not_to have_text("View results")
      end
    end

    describe "when ended" do
      before do
        hunt.update(ends_at: 1.hour.ago)
      end

      it "shows the timer" do
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        expect(page).to have_text("Hunt over. No more submissions.")
      end

      it "shows the view results button" do
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        expect(page).to have_text("View results")
      end

      it "tells the team the hunt is over instead of how to take photos" do
        visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
        expect(page).to have_text("The hunt is over.")
        expect(page).not_to have_text("Tap an item to take a photo")
      end

      it "keeps the progress text and the timer pill on one line each on a phone" do
        30.times { |i| create(:item, category: hunt.categories.first, name: "Thing #{i + 1}") }
        emulate_viewport(390, 844)
        visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
        expect(page).to have_text("0 of 33 found")
        expect(page).to have_text("Hunt over. No more submissions.")

        lines = page.evaluate_script(<<~JS)
          ["[data-checklist-target='progress']", "[data-timer-target='countdown']"].map((selector) => {
            const element = document.querySelector(selector)
            return Math.round(element.getBoundingClientRect().height / parseFloat(getComputedStyle(element).lineHeight))
          })
        JS
        expect(lines).to eq([1, 1])
      end
    end
  end

  context "results" do
    it "unlocks with the correct password" do
      hunt = create(:hunt, lock_password: "password", lock_results: true)
      visit "/scavenger_hunts/#{hunt.code.upcase}/results"
      expect(page).to have_text("Results are not yet available!")
      fill_in "Password", with: "password"
      click_on "Unlock results"
      expect(page).to have_text("Let's see how everyone did!")
    end

    it "shows an error with an incorrect password" do
      hunt = create(:hunt, lock_password: "password", lock_results: true)
      visit "/scavenger_hunts/#{hunt.code.upcase}/results"
      expect(page).to have_text("Results are not yet available!")
      fill_in "Password", with: "wrong"
      click_on "Unlock results"
      expect(page).to have_text("Incorrect password")
    end
  end
end
