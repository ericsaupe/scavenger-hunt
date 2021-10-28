# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Item, type: :model do
  context 'associations' do
    it { should belong_to(:category).class_name('Category') }
    it { should have_many(:submissions).class_name('Submission') }
    it { should have_many(:teams).class_name('Team') }
  end
end
