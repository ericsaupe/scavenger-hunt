# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hunt, type: :model do
  context 'associations' do
    it { is_expected.to have_many(:categories).class_name('Category') }
    it { is_expected.to have_many(:items).class_name('Item') }
    it { is_expected.to have_many(:teams).class_name('Team') }
  end

  it 'sets code on create' do
    hunt = described_class.new(name: 'Test')
    expect(hunt.code).to be_nil
    hunt.save!
    expect(hunt.code).not_to be_nil
  end

  it 'does not replace code if one is present' do
    hunt = described_class.new(name: 'Test', code: 'TEST')
    expect(hunt.code).to eq('TEST')
    hunt.save!
    expect(hunt.code).to eq('TEST')
  end

  describe '#in_progress?' do
    let(:hunt) { create(:hunt) }

    describe 'when true' do
      it 'has no dates set' do
        expect(hunt).to be_in_progress
      end

      it 'starts in the past' do
        hunt.update(starts_at: Time.current - 1.day)
        expect(hunt).to be_in_progress
      end

      it 'ends in the past' do
        hunt.update(ends_at: Time.current + 1.day)
        expect(hunt).to be_in_progress
      end

      it 'is between the start and end' do
        hunt.update(starts_at: Time.current - 1.day, ends_at: Time.current + 1.day)
        expect(hunt).to be_in_progress
      end
    end

    describe 'when false' do
      it 'starts in the future' do
        hunt.update(starts_at: Time.current + 1.day)
        expect(hunt).not_to be_in_progress
      end

      it 'ends in the past' do
        hunt.update(ends_at: Time.current - 1.day)
        expect(hunt).not_to be_in_progress
      end
    end
  end
end
