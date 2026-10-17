# frozen_string_literal: true

class AddAnnouncementToMessages < ActiveRecord::Migration[8.1]
  def change
    add_column :messages, :announcement, :boolean, null: false, default: false
    remove_index :messages, [:hunt_id, :organizer, :id]
    add_index :messages, [:hunt_id, :announcement, :id]
  end
end
