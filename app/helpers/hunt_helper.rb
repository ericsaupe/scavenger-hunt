# frozen_string_literal: true

module HuntHelper
  def hunt_status(hunt)
    return if hunt.starts_at.nil? && hunt.ends_at.nil?

    text = if hunt.reopened?
      "Reopened · #{distance_of_time_in_words(Time.current, hunt.ends_at)} left"
    elsif hunt.in_progress? && hunt.ends_at
      "Ends in #{distance_of_time_in_words(Time.current, hunt.ends_at)}"
    elsif hunt.upcoming?
      "Starts in #{distance_of_time_in_words(Time.current, hunt.starts_at)}"
    elsif hunt.ended?
      "Hunt over. No more submissions."
    end

    content_tag(:span, text)
  end

  def hunt_qr_code_svg(hunt)
    RQRCode::QRCode.new(hunt_url(hunt.code.upcase)).as_svg(fill: "fff", viewbox: true).html_safe
  end

  def timer_state(hunt)
    return "ended" if hunt.ended?
    return "reopened" if hunt.reopened?
    return "upcoming" if hunt.upcoming?
    "live"
  end

  def timer_phase(hunt)
    return "ended" if hunt.ended?
    return "reopened" if hunt.reopened?
    "open"
  end

  def push_preference_options
    {
      notify_starting_soon: ["Hunt starting soon", "Five minutes before the start"],
      notify_results: ["Results are up", "When the hunt ends"],
      notify_show: ["The show is starting", "When photos go up on the big screen"],
      notify_lead_change: ["Lead changes", "When a new team takes the top spot"],
      notify_announcements: ["Organizer announcements", "When the organizer posts in Party chat"]
    }
  end

  def template_summary(template)
    [
      pluralize(template.item_count, "item"),
      pluralize(template.categories.size, "group"),
      template_points_summary(template)
    ].join(" · ")
  end

  def template_points_summary(template)
    range = template.points_range
    return "#{pluralize(range.min, "point")} each" if range.min == range.max

    "#{range.min} to #{range.max} points"
  end

  def template_points_each(template)
    range = template.points_range
    (range.min == range.max) ? "#{range.min} each" : "#{range.min} to #{range.max} each"
  end

  def checklist_folds(team)
    folds = JSON.parse(cookies["checklist_#{team.id}"].to_s)
    folds.is_a?(Hash) ? folds : {}
  rescue JSON::ParserError
    {}
  end

  def found_count(found, total)
    (total.positive? && found == total) ? "All #{total} found" : "#{found} of #{total} found"
  end

  def time_left(hunt)
    seconds = [(hunt.ends_at - Time.current).ceil, 0].max
    format("%d:%02d", seconds / 60, seconds % 60)
  end

  def clock_time(time)
    tag.time(time.strftime("%-l:%M %p"), datetime: time.iso8601, data: {reopen_target: "time"})
  end

  def reopen_data(hunt)
    {
      controller: "live reopen",
      live_interval_value: 30_000,
      reopen_ends_at_value: (hunt.ends_at.to_f * 1000).round,
      reopen_opened_at_value: (hunt.reopened_at.to_f * 1000).round,
      reopen_now_value: (Time.current.to_f * 1000).round
    }
  end
end
