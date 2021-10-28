# frozen_string_literal: true

class CreateCategories < ActiveRecord::Migration[7.0]
  def change
    create_table :categories do |t|
      t.belongs_to :hunt, null: false, index: true
      t.string :name, blank: false, null: false
      t.integer :points

      t.timestamps
    end
  end
end
