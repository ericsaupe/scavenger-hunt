# frozen_string_literal: true

class AddAvatars < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :avatar_seed, :string, limit: 16, null: false, default: -> { "substr(md5(random()::text), 1, 16)" }

    create_table :avatars do |t|
      t.string :kind, null: false
      t.string :digest, limit: 64, null: false
      t.text :svg, null: false
      t.timestamps
      t.index [:kind, :digest], unique: true
    end
  end
end
