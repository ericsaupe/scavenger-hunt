# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Hunts', type: :system do
  context 'creating a hunt' do
    it 'creates a new hunt' do
      visit '/'
      click_on 'Browse our premade scavenger hunts to get started!'
      click_link 'Start', match: :first
      fill_in('Name', with: 'My Fun Scavenger Hunt')
      find('input#hunt_starts_at', visible: false).execute_script("this.value = '2020-01-01 12:00'")
      find('input#hunt_ends_at', visible: false).execute_script("this.value = '2020-02-01 12:00'")
      click_on 'Get started!'
      expect(page).to have_text('My Fun Scavenger Hunt'.upcase)
      expect(page).to have_text('Available Teams'.upcase)
      expect(page).to have_text('Print List')
    end

    it 'supports locking' do
      visit '/'
      click_on 'Browse our premade scavenger hunts to get started!'
      click_link 'Start', match: :first
      fill_in('Name', with: 'My Fun Scavenger Hunt')
      # TODO: this is a hack to get around the fact that the datepicker is not visible
      find('input#hunt_starts_at', visible: false).execute_script("this.value = '2020-01-01 12:00'")
      find('input#hunt_ends_at', visible: false).execute_script("this.value = '2020-02-01 12:00'")
      # TODO: this is a hack to fill in hidden fields
      find('input#hunt_lock_results', visible: false).execute_script('this.checked = true')
      find('input#hunt_lock_password', visible: false).execute_script("this.value = 'hunter2'")
      click_on 'Get started!'
      expect(page).to have_text('My Fun Scavenger Hunt'.upcase)
      expect(page).to have_text('Available Teams'.upcase)
      expect(page).to have_text('Print List')
      hunt = Hunt.last
      expect(hunt.lock_results).to be_truthy
      expect(hunt.lock_password).to be_present
    end
  end

  context 'with a hunt started' do
    let(:hunt) { create(:hunt) }
    let(:team) { create(:team, hunt: hunt) }

    it 'creates a team' do
      visit "/scavenger_hunts/#{hunt.code.upcase}"
      fill_in 'New Team Name', with: 'Test'
      click_on "Let's Go!"
      expect(page).to have_text('Test'.upcase)
      expect(page).to have_text('Find the following items to earn points for your team. Take a picture or video for evidence!')
    end

    it 'joins a team' do
      team_name = team.name
      visit "/scavenger_hunts/#{hunt.code.upcase}"
      select(team_name, from: 'Available Teams')
      click_on "Let's Go!"
      expect(page).to have_text(team_name.upcase)
      expect(page).to have_text('Find the following items to earn points for your team. Take a picture or video for evidence!')
    end

    it 'crosses off an item' do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      attach_file(Rails.root.join('spec/fixtures/test.jpg')) do
        find(:label, text: hunt.items.first.name).click
      end
      expect(page).to have_css('ion-icon[name="checkbox"]')
    end

    it 'supports video' do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      attach_file(Rails.root.join('spec/fixtures/video.mp4')) do
        find(:label, text: hunt.items.first.name).click
      end
      expect(page).to have_css('ion-icon[name="checkbox"]')
    end

    it 'does not cross off if hunt ended' do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      hunt.update(ends_at: 1.day.ago)
      attach_file(Rails.root.join('spec/fixtures/test.jpg')) do
        find(:label, text: hunt.items.first.name).click
      end
      expect(page).not_to have_css('ion-icon[name="checkbox"]')
    end

    it 'changes the image' do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      attach_file(Rails.root.join('spec/fixtures/test.jpg')) do
        find(:label, text: hunt.items.first.name).click
      end
      expect(page).to have_css('ion-icon[name="checkbox"]')

      find('.cursor-pointer', text: hunt.items.first.name).click
      expect(page).to have_text('Change')
      attach_file(Rails.root.join('spec/fixtures/test.jpg')) do
        find(:button, text: 'Change').click
      end
      expect(page).to have_css('ion-icon[name="checkbox"]')
    end

    it 'closes the modal' do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      attach_file(Rails.root.join('spec/fixtures/test.jpg')) do
        find(:label, text: hunt.items.first.name).click
      end
      expect(page).to have_css('ion-icon[name="checkbox"]')

      find('.cursor-pointer', text: hunt.items.first.name).click
      expect(page).to have_text('Close')
      click_on 'Close'
      expect(page).not_to have_text('Close')
    end

    it 'updates the score' do
      visit "/scavenger_hunts/#{hunt.code.upcase}/teams/#{team.id}"
      expect(page).to have_text('Score: 0')
      item = hunt.items.first
      points = item.category.points
      attach_file(Rails.root.join('spec/fixtures/test.jpg')) do
        find(:label, text: item.name).click
      end
      expect(page).to have_text("Score: #{points}")
    end

    it 'prints' do
      visit "/scavenger_hunts/#{hunt.code.upcase}/print"
      expect(page).to have_text("Code: #{hunt.code.upcase}")
      expect(page).to have_css('.qr-code')
    end

    context 'when remembering' do
      it 'remembers past hunts' do
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        visit '/'
        expect(page).to have_text('Rejoin a scavenger hunt')
        select(hunt.name, from: 'Rejoin a scavenger hunt you participated in!')
        click_on 'Rejoin the scavenger hunt'
        expect(page).to have_text('Available Teams'.upcase)

        second_hunt = create(:hunt)
        visit "/scavenger_hunts/#{second_hunt.code.upcase}"
        visit '/'
        expect(page).to have_text('Rejoin a scavenger hunt')
        select(second_hunt.name, from: 'Rejoin a scavenger hunt you participated in!')
        click_on 'Rejoin the scavenger hunt'
        expect(page).to have_text('Available Teams'.upcase)
      end
    end
  end

  context 'timers' do
    let(:hunt) { create(:hunt) }
    let(:team) { create(:team, hunt: hunt) }

    describe 'when starting' do
      before do
        hunt.update(starts_at: 1.hour.from_now)
      end

      it 'shows the timer' do
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        expect(page).to have_text('Starts in')
      end
    end

    describe 'when in progress' do
      before do
        hunt.update(ends_at: 1.hour.from_now)
      end

      it 'shows the timer' do
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        expect(page).to have_text('Ends in')
      end
    end

    describe 'when ended' do
      before do
        hunt.update(ends_at: 1.hour.ago)
      end

      it 'shows the timer' do
        visit "/scavenger_hunts/#{hunt.code.upcase}"
        expect(page).to have_text('This scavenger hunt has ended. No more submissions will be accepted.')
      end
    end
  end
end
