# frozen_string_literal: true

class PageHeaderComponent < ViewComponent::Base
  def initialize(title:, subtitle: nil, link_to: nil, back_to: nil, back_label: "Back")
    @title = title
    @subtitle = subtitle
    @link_to = link_to
    @back_to = back_to
    @back_label = back_label
  end
end
