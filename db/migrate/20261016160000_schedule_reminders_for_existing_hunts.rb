# frozen_string_literal: true

class ScheduleRemindersForExistingHunts < ActiveRecord::Migration[8.1]
  def up
    Hunt.reset_column_information
    Hunt.where("starts_at > :now OR ends_at > :now", now: Time.current).find_each(&:schedule_notifications)
  end

  def down
  end
end
