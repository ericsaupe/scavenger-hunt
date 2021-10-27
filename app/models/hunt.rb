# frozen_string_literal: true

class Hunt < ApplicationRecord
  before_save :generate_code, if: :new_record?

  private

  def generate_code
    new_code = ('A'..'Z').to_a.sample(4).join
    while Hunt.find_by(code: new_code).present?
      new_code = ('A'..'Z').to_a.sample(4).join
    end
    self.code = new_code
  end
end
