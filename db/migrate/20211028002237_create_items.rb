# frozen_string_literal: true

class CreateItems < ActiveRecord::Migration[7.0]
  def change
    create_table :items do |t|
      t.belongs_to :category, null: false, index: true
      t.string :name, blank: false, null: false

      t.timestamps
    end
  end
end
