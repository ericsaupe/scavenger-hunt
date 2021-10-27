# frozen_string_literal: true

class CreateHunts < ActiveRecord::Migration[7.0]
  def change
    create_table :hunts do |t|
      t.string :name, blank: false, null: false
      t.string :code, index: true

      t.timestamps
    end
  end
end
