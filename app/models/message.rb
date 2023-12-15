class Message < ApplicationRecord
  belongs_to :hunt

  validates :content, :user_id, presence: true

  after_create_commit { broadcast_append_to("hunts_chat_#{hunt_id}", target: "hunt_chat_#{hunt_id}") }
end
