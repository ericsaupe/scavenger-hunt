# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Hunts', type: :system do
  it 'creates a new hunt' do
    visit '/'
    select 'Neighborhood Scavenger Hunt', from: 'Select a scavenger hunt to start your own!'
    click_on 'Start my scavenger hunt!'
    expect(page).to have_text('Available Teams'.upcase)
    expect(page).to have_text('Print List')
  end

  context 'hunt started' do
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
      expect(page).to have_text('Cancel')
      click_on 'Cancel'
      expect(page).not_to have_text('Cancel')
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

    it 'remembers past hunts' do
      visit "/scavenger_hunts/#{hunt.code.upcase}"
      visit '/'
      expect(page).to have_text('Rejoin a scavenger hunt')
      select(hunt.name, from: 'Rejoin a scavenger hunt you participated in!')
      click_on 'Rejoin the scavenger hunt'
      expect(page).to have_text('Available Teams'.upcase)
    end
  end
end
