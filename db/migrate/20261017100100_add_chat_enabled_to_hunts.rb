# frozen_string_literal: true

class AddChatEnabledToHunts < ActiveRecord::Migration[8.1]
  def change
    add_column :hunts, :chat_enabled, :boolean, null: false, default: true
  end
end
