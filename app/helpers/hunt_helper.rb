# frozen_string_literal: true

module HuntHelper
  def hunt_status(hunt)
    return if hunt.starts_at.nil? && hunt.ends_at.nil?

    text = if hunt.in_progress? && hunt.ends_at
      "Ends in #{distance_of_time_in_words(Time.current, hunt.ends_at)}"
    elsif hunt.upcoming?
      "Starts in #{distance_of_time_in_words(Time.current, hunt.starts_at)}"
    elsif hunt.ended?
      "This scavenger hunt has ended. No more submissions will be accepted."
    end

    content_tag(:span, text)
  end

  def timer_background(hunt)
    return "bg-error text-error-content" if hunt.ended?
    return "bg-success text-success-content" if hunt.in_progress?
    "bg-info text-info-content" if hunt.upcoming?
  end
end
