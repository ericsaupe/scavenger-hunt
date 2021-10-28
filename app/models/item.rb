# frozen_string_literal: true

class Item < ApplicationRecord
  belongs_to :category
end
