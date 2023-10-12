# frozen_string_literal: true

class AddLockingToResults < ActiveRecord::Migration[7.0]
  def change
    change_table :hunts, bulk: true do |t|
      t.boolean :lock_results, default: false, null: false
      t.string :lock_password
      t.boolean :password_entered, default: false, null: false
    end
  end
end
