# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Item, type: :model do
  context 'associations' do
    it { should belong_to(:category).class_name('Category') }
  end
end
