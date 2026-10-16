# frozen_string_literal: true

class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions do |t|
      t.references :hunt, null: false, foreign_key: true
      t.string :user_id, null: false
      t.string :endpoint, null: false
      t.string :p256dh, null: false
      t.string :auth, null: false
      t.string :user_agent
      t.boolean :notify_starting_soon, null: false, default: true
      t.boolean :notify_results, null: false, default: true
      t.boolean :notify_show, null: false, default: true
      t.boolean :notify_lead_change, null: false, default: true
      t.timestamps
    end
    add_index :push_subscriptions, [:hunt_id, :user_id], unique: true

    change_table :hunts do |t|
      t.datetime :show_announced_at
      t.integer :leading_team_id
      t.datetime :lead_announced_at
      t.datetime :lead_recheck_at
    end
  end
end
