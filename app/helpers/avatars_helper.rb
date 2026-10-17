# frozen_string_literal: true

module AvatarsHelper
  def avatar_image(src, still_src, size:, img_class: nil, **options)
    picture_class = options.delete(:class)
    tag.picture(class: ["inline-block shrink-0 rounded-full align-middle", picture_class]) do
      safe_join([
        tag.source(srcset: still_src, media: "(prefers-reduced-motion: reduce)"),
        tag.img(src:, width: size, height: size, loading: "lazy", alt: "", class: ["avatar-img", img_class], **options)
      ])
    end
  end

  def team_avatar(team, size:, **options)
    avatar_image(team.avatar_url, team.avatar_url(still: true), size:, data: {testid: "team-avatar"}, **options)
  end

  def sender_avatar(message, size:, **options)
    avatar_image(message.avatar_url, message.avatar_url(still: true), size:, data: {testid: "sender-avatar"}, **options)
  end
end
