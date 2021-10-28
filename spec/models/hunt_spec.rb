# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Hunt, type: :model do
  context 'associations' do
    it { should have_many(:categories).class_name('Category') }
    it { should have_many(:items).class_name('Item') }
  end

  it 'sets code on create' do
    hunt = Hunt.new(name: 'Test')
    expect(hunt.code).to be_nil
    hunt.save!
    expect(hunt.code).not_to be_nil
  end

  it 'does not replace code if one is present' do
    hunt = Hunt.new(name: 'Test', code: 'TEST')
    expect(hunt.code).to eq('TEST')
    hunt.save!
    expect(hunt.code).to eq('TEST')
  end
end
