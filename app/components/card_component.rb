# frozen_string_literal: true

class CardComponent < ViewComponent::Base
  def initialize(class_list: [])
    @class_list = class_list
  end
end
