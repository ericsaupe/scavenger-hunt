# frozen_string_literal: true

class AddReopenedAtToHunts < ActiveRecord::Migration[8.1]
  def change
    add_column :hunts, :reopened_at, :datetime
  end
end
