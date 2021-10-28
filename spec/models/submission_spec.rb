# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Submission, type: :model do
  context 'associations' do
    it { should belong_to(:item).class_name('Item') }
    it { should belong_to(:team).class_name('Team') }
  end
end
