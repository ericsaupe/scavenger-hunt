# frozen_string_literal: true

module PresentationHelper
  CONFETTI_COLORS = %w[#ffb703 #d7263d #2452e0 #ffffff #1f9d55].freeze

  def print_tilt(submission)
    (((submission.id * 7919) % 31) / 10.0 - 1.5).round(1)
  end

  def remote_data(hunt, slide)
    code = hunt.code.upcase
    {
      controller: "remote live",
      remote_url_value: hunt_presentation_path(code),
      remote_playback_url_value: playback_hunt_presentation_path(code),
      remote_screen_chat_url_value: screen_chat_hunt_presentation_path(code),
      remote_reveal_url_value: reveal_hunt_presentation_path(code),
      remote_playing_value: hunt.playing?,
      remote_video_value: slide.video?,
      live_refresh_at_value: (hunt.ends_at.iso8601 if hunt.time_locked?)
    }
  end

  def static_confetti(count: 60)
    random = Random.new(count)
    safe_join(Array.new(count) do |i|
      tag.span(class: "confetti",
        style: "left:#{random.rand(100)}%;top:#{random.rand(100)}%;--rotate:#{random.rand(360)}deg;--scale:#{random.rand(0.6..1.4).round(2)};background:#{CONFETTI_COLORS[i % CONFETTI_COLORS.size]}")
    end)
  end
end
