# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submission do
  context 'associations' do
    it { is_expected.to belong_to(:item).class_name('Item') }
    it { is_expected.to belong_to(:team).class_name('Team') }
  end

  context 'after_update_commit' do
    describe '#process_variants' do
      let(:submission) { create(:submission) }

      it 'calls process_variants_later' do
        allow(submission).to receive(:process_variants_later)
        submission.save
        expect(submission).to have_received(:process_variants_later)
      end
    end
  end
end
