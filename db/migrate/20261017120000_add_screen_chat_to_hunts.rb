# frozen_string_literal: true

class AddScreenChatToHunts < ActiveRecord::Migration[8.1]
  def change
    add_column :hunts, :screen_chat, :string, default: "off", null: false
  end
end
