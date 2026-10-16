# frozen_string_literal: true

module HuntHelper
  def hunt_status(hunt)
    return if hunt.starts_at.nil? && hunt.ends_at.nil?

    text = if hunt.in_progress? && hunt.ends_at
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
    return "upcoming" if hunt.upcoming?
    "live"
  end

  def template_item_count(template)
    template[:categories].sum { |category| category[:items].size }
  end
end
