# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Team, type: :model do
  context 'associations' do
    it { should belong_to(:hunt).class_name('Hunt') }
    it { should have_many(:submissions).class_name('Submission') }
    it { should have_many(:items).class_name('Item') }
  end
end
