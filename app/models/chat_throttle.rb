# frozen_string_literal: true

class ChatThrottle
  INTERVAL = 1.second

  def self.allow?(hunt, user_id)
    Rails.cache.write("chat/#{hunt.id}/#{user_id}", true, unless_exist: true, expires_in: INTERVAL)
  end
end
