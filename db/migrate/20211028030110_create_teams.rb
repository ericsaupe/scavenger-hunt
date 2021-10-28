# frozen_string_literal: true

class CreateTeams < ActiveRecord::Migration[7.0]
  def change
    create_table :teams do |t|
      t.belongs_to :hunt, null: false, index: true
      t.string :name, blank: false, null: false

      t.timestamps
    end
  end
end
