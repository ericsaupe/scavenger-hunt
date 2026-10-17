# frozen_string_literal: true

class AddNotifyAnnouncementsToPushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    add_column :push_subscriptions, :notify_announcements, :boolean, null: false, default: true
  end
end
