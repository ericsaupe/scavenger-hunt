# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hunt do
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
        hunt.update(starts_at: 1.day.ago)
        expect(hunt).to be_in_progress
      end

      it 'ends in the past' do
        hunt.update(ends_at: 1.day.from_now)
        expect(hunt).to be_in_progress
      end

      it 'is between the start and end' do
        hunt.update(starts_at: 1.day.ago, ends_at: 1.day.from_now)
        expect(hunt).to be_in_progress
      end
    end

    describe 'when false' do
      it 'starts in the future' do
        hunt.update(starts_at: 1.day.from_now)
        expect(hunt).not_to be_in_progress
      end

      it 'ends in the past' do
        hunt.update(ends_at: 1.day.ago)
        expect(hunt).not_to be_in_progress
      end
    end
  end

  describe '#results_locked?' do
    let(:hunt) { create(:hunt) }

    describe 'when true' do
      it 'is true when a password is present and not entered yet' do
        hunt.update(ends_at: nil, password: 'hunter2', password_entered: false)
        expect(hunt).to be_results_locked
        hunt.update(ends_at: 1.month.ago, password: 'hunter2', password_entered: false)
        expect(hunt).to be_results_locked
      end

      it 'is true when the end is in the future and results are locked' do
        hunt.update(ends_at: 1.month.from_now, lock_results: true)
        expect(hunt).to be_results_locked
      end
    end

    describe 'when false' do
      it 'is false when there is a password and it has been entered' do
        hunt.update(password: 'hunter2', password_entered: true)
        expect(hunt).not_to be_results_locked
      end

      it 'is false when the end is in the past and no password' do
        hunt.update(ends_at: 1.month.ago, lock_results: true)
        expect(hunt).not_to be_results_locked
      end

      it 'is false by default' do
        expect(hunt).not_to be_results_locked
      end
    end
  end
end
