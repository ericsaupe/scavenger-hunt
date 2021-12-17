# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Results', type: :system do
  context 'with a hunt started' do
    let(:hunt) { create(:hunt) }
    let(:team) { video_submission.team }
    let(:video_submission) { create(:video_submission, item: hunt.items.first) }
    let(:photo_submission) { create(:photo_submission, item: hunt.items.second, team: team) }

    describe 'results page' do
      it 'displays the results' do
        visit "/scavenger_hunts/#{hunt.code}/results"
        expect(page).to have_content(hunt.name.upcase)
        expect(page).to have_content(team.score)
      end
    end

    describe 'single result page' do
      it 'displays the video submission' do
        visit "scavenger_hunts/#{hunt.code}/items/#{video_submission.item_id}"
        expect(page).to have_content(team.name)
      end

      it 'displays the photo submission' do
        visit "scavenger_hunts/#{hunt.code}/items/#{photo_submission.item_id}"
        expect(page).to have_content(team.name)
      end
    end
  end
end
