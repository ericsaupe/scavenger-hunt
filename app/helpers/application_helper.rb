# frozen_string_literal: true

module ApplicationHelper
  def daisy_theme
    case Time.zone.now.month
    when 10 then "halloween"
    when 11, 12 then "autumn"
    else "party"
    end
  end
end
