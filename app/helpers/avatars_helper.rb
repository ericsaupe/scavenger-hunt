# frozen_string_literal: true

module AvatarsHelper
  def avatar_image(src, size:, **options)
    tag.img(src:, width: size, height: size, loading: "lazy", alt: "", **options, class: ["avatar-img", options[:class]])
  end

  def team_avatar(team, size:, **options)
    avatar_image(team.avatar_url, size:, data: {testid: "team-avatar"}, **options)
  end

  def sender_avatar(message, size:, **options)
    avatar_image(message.avatar_url, size:, data: {testid: "sender-avatar"}, **options)
  end
end
