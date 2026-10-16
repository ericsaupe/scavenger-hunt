# frozen_string_literal: true

module PresentationHelper
  CONFETTI_COLORS = %w[#ffb703 #d7263d #2452e0 #ffffff #1f9d55].freeze

  def print_tilt(submission)
    (((submission.id * 7919) % 31) / 10.0 - 1.5).round(1)
  end

  def static_confetti(count: 60)
    random = Random.new(count)
    safe_join(Array.new(count) do |i|
      tag.span(class: "confetti",
        style: "left:#{random.rand(100)}%;top:#{random.rand(100)}%;--rotate:#{random.rand(360)}deg;--scale:#{random.rand(0.6..1.4).round(2)};background:#{CONFETTI_COLORS[i % CONFETTI_COLORS.size]}")
    end)
  end
end
