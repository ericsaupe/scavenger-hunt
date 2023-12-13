# frozen_string_literal: true

module ApplicationHelper
  def daisy_theme
    Rails.cache.fetch("daisy_theme", expires_in: 1.day) do
      current_time = Time.zone.now
      if current_time.month == 10 # October
        "halloween"
      elsif current_time.month == 11 || current_time.month == 12 # November/December
        "autumn"
      else
        "cmyk"
      end
    end
  end
end
