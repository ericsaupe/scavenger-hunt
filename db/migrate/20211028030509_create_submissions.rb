# frozen_string_literal: true

class CreateSubmissions < ActiveRecord::Migration[7.0]
  def change
    create_table :submissions do |t|
      t.belongs_to :item, null: false, index: true
      t.belongs_to :team, null: false, index: true

      t.timestamps
    end

    add_index :submissions, [:item_id, :team_id]
  end
end
