# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Hunts" do
  context "creating a hunt" do
    it "creates a new hunt" do
      visit "/"
      click_on "Start"
      within("#content") do
        click_link "Start", match: :first
      end
      fill_in("What do you want to call your scavenger hunt?", with: "My Fun Scavenger Hunt")
      find("input#hunt_starts_at", visible: false).execute_script("this.value = '2020-01-01 12:00'")
      find("input#hunt_ends_at", visible: false).execute_script("this.value = '2020-02-01 12:00'")
      click_on "Start!"
      expect(page).to have_text("My Fun Scavenger Hunt".upcase)
      expect(page).to have_text("Pick a team".upcase)
      expect(page).to have_text("Print List")
    end

    it "supports locking" do
      visit "/"
      click_on "Start"
      within("#content") do
        click_link "Start", match: :first
      end
      fill_in("What do you want to call your scavenger hunt?", with: "My Fun Scavenger Hunt")
      # TODO: this is a hack to get around the fact that the datepicker is not visible
      find("input#hunt_starts_at", visible: false).execute_script("this.value = '2020-01-01 12:00'")
      find("input#hunt_ends_at", visible: false).execute_script("this.value = '2020-02-01 12:00'")
      # TODO: this is a hack to fill in hidden fields
      find("input#hunt_lock_results", visible: false).execute_script("this.checked = true")
      find("input#hunt_lock_password", visible: false).execute_script("this.value = 'hunter2'")
      click_on "Start!"
      expect(page).to have_text("My Fun Scavenger Hunt".upcase)
      expect(page).to have_text("Pick a team".upcase)
      expect(page).to have_text("Print List")
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
      fill_in "Start a team", with: "Test"
      click_on "Start!"
      expect(page).to have_text("Test".upcase)
      expect(page).to have_text("Find the following items to earn points for your team. Take a picture or video for evidence!")
    end

    it "requires a name to start a team" do
      visit "/scavenger_hunts/#{hunt.code.upcase}"
      click_on "Start!"
      expect(page).to have_text("Please select a team or enter a team name")
    end

    it "joins a team" do
      team_name = team.name
      visit "/scavenger_hunts/#{hunt.code.upcase}"
      choose(team_name)
      click_on "Start!"
      expect(page).to have_text(team_name.upcase)
      expect(page).to have_text("Find the following items to earn points for your team. Take a picture or video for evidence!")
    end

    it "crosses off an item" do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      attach_file(Rails.root.join("spec/fixtures/test.jpg")) do
        find(:label, text: hunt.items.first.name).click
      end
      expect(page).to have_css('ion-icon[name="checkbox"]')
    end

    it "supports video" do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      attach_file(Rails.root.join("spec/fixtures/video.mp4")) do
        find(:label, text: hunt.items.first.name).click
      end
      expect(page).to have_css('ion-icon[name="checkbox"]')
    end

    it "does not cross off if hunt ended" do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      hunt.update(ends_at: 1.day.ago)
      attach_file(Rails.root.join("spec/fixtures/test.jpg")) do
        find(:label, text: hunt.items.first.name).click
      end
      expect(page).not_to have_css('ion-icon[name="checkbox"]')
    end

    it "changes the image" do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      attach_file(Rails.root.join("spec/fixtures/test.jpg")) do
        find(:label, text: hunt.items.first.name).click
      end
      expect(page).to have_css('ion-icon[name="checkbox"]')

      find(".cursor-pointer", text: hunt.items.first.name).click
      expect(page).to have_text("Change")
      attach_file(Rails.root.join("spec/fixtures/test.jpg")) do
        find(:button, text: "Change").click
      end
      expect(page).to have_css('ion-icon[name="checkbox"]')
    end

    it "closes the modal" do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      attach_file(Rails.root.join("spec/fixtures/test.jpg")) do
        find(:label, text: hunt.items.first.name).click
      end
      expect(page).to have_css('ion-icon[name="checkbox"]')

      find(".cursor-pointer", text: hunt.items.first.name).click
      expect(page).to have_text("Close")
      click_on "Close"
      expect(page).not_to have_text("Close")
    end

    it "updates the score" do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      expect(page).to have_text("Score: 0")
      item = hunt.items.first
      points = item.category.points
      attach_file(Rails.root.join("spec/fixtures/test.jpg")) do
        find(:label, text: item.name).click
      end
      expect(page).to have_text("Score: #{points}")
    end

    it "prints" do
      visit "/scavenger_hunts/#{hunt.code.upcase}/print"
      expect(page).to have_text("Code: #{hunt.code.upcase}")
      expect(page).to have_css(".qr-code")
    end

    context "when remembering" do
      it "remembers past hunts" do
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        visit "/"
        click_on "Join"
        select(hunt.name, from: "hunt_select")
        click_on "Rejoin the scavenger hunt"
        expect(page).to have_text("Pick a team".upcase)

        second_hunt = create(:hunt)
        visit "/scavenger_hunts/#{second_hunt.code.upcase}"
        visit "/"
        click_on "Join"
        select(second_hunt.name, from: "hunt_select")
        click_on "Rejoin the scavenger hunt"
        expect(page).to have_text("Pick a team".upcase)
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
        expect(page).not_to have_text("View Results!")
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
        expect(page).not_to have_text("View Results!")
      end
    end

    describe "when ended" do
      before do
        hunt.update(ends_at: 1.hour.ago)
      end

      it "shows the timer" do
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        expect(page).to have_text("This scavenger hunt has ended. No more submissions will be accepted.")
      end

      it "shows the view results button" do
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        expect(page).to have_text("View Results!")
      end
    end
  end

  context "results" do
    it "unlocks with the correct password" do
      hunt = create(:hunt, lock_password: "password", lock_results: true)
      visit "/scavenger_hunts/#{hunt.code.upcase}/results"
      expect(page).to have_text("Results are not yet available!")
      fill_in "Password", with: "password"
      click_on "Unlock Results!"
      expect(page).to have_text("Let's see how everyone did!")
    end

    it "shows an error with an incorrect password" do
      hunt = create(:hunt, lock_password: "password", lock_results: true)
      visit "/scavenger_hunts/#{hunt.code.upcase}/results"
      expect(page).to have_text("Results are not yet available!")
      fill_in "Password", with: "wrong"
      click_on "Unlock Results!"
      expect(page).to have_text("Incorrect password")
    end
  end
end
