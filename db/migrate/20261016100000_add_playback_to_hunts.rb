# frozen_string_literal: true

class AddPlaybackToHunts < ActiveRecord::Migration[8.1]
  def change
    change_table :hunts, bulk: true do |t|
      t.string :presentation_playback, null: false, default: "paused"
      t.boolean :presentation_muted, null: false, default: true
      t.integer :playback_version, null: false, default: 0
      t.datetime :playback_started_at
    end
  end
end
