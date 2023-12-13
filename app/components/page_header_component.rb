# frozen_string_literal: true

class PageHeaderComponent < ViewComponent::Base
  def initialize(title:, subtitle: nil, link_to: nil)
    @title = title
    @subtitle = subtitle
    @link_to = link_to
  end
end
