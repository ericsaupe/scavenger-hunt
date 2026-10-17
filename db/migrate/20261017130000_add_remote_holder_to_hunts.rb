# frozen_string_literal: true

class AddRemoteHolderToHunts < ActiveRecord::Migration[8.1]
  def change
    add_column :hunts, :remote_holder_id, :string
  end
end
