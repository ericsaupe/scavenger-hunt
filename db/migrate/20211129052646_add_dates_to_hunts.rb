# frozen_string_literal: true

class AddDatesToHunts < ActiveRecord::Migration[7.0]
  def change
    change_table :hunts, bulk: true do |t|
      t.datetime :starts_at
      t.datetime :ends_at
    end
  end
end
