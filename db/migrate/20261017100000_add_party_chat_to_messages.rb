# frozen_string_literal: true

class AddPartyChatToMessages < ActiveRecord::Migration[8.1]
  def change
    change_table :messages, bulk: true do |t|
      t.string :sender_name, limit: 40
      t.references :team, foreign_key: true, index: true
      t.boolean :organizer, null: false, default: false
      t.datetime :deleted_at
    end
    add_index :messages, [:hunt_id, :organizer, :id]
  end
end
