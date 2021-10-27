# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Hunt', type: :model do
  it 'sets code on create' do
    hunt = Hunt.new(name: 'Test')
    expect(hunt.code).to be_nil
    hunt.save!
    expect(hunt.code).not_to be_nil
  end
end
