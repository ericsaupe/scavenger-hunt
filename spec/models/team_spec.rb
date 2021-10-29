# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Team, type: :model do
  context 'associations' do
    it { should belong_to(:hunt).class_name('Hunt') }
    it { should have_many(:submissions).class_name('Submission') }
    it { should have_many(:items).class_name('Item') }
  end

  context 'unique names' do
    let(:team) { create(:team) }

    it 'does not allow duplicate neams within the same hunt' do
      [team.name, team.name.upcase, team.name.downcase].each do |name|
        new_team = build(:team, hunt: team.hunt, name: name)
        expect(new_team).not_to be_valid
      end

      different_hunt_team = build(:team, name: team.name)
      expect(different_hunt_team).to be_valid
    end
  end
end
