# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Team, type: :model do
  context 'associations' do
    it { should belong_to(:hunt).class_name('Hunt') }
  end
end
