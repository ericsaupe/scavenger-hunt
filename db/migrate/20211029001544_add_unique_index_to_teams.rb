# frozen_string_literal: true

class AddUniqueIndexToTeams < ActiveRecord::Migration[7.0]
  def change
    add_index :teams, [:hunt_id, :name], unique: true
  end
end
