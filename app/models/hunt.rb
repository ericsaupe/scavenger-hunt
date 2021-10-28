# frozen_string_literal: true

class Hunt < ApplicationRecord
  has_many :categories, dependent: :destroy
  has_many :items, through: :categories
  has_many :teams, dependent: :destroy

  before_save :generate_code, if: :new_record?

  private

  ##
  # Generate a code to be used for better UX. If one is already set double check that it is unique
  # and if it's not then generate a new one.
  #
  def generate_code(character_count: 4)
    new_code = code || ('A'..'Z').to_a.sample(character_count).join
    while Hunt.find_by(code: new_code).present?
      new_code = ('A'..'Z').to_a.sample(character_count).join
    end
    self.code = new_code
  end
end
