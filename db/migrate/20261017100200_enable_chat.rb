# frozen_string_literal: true

class EnableChat < ActiveRecord::Migration[8.1]
  def up
    Flipper.enable(:chat)
  end

  def down
    Flipper.remove(:chat)
  end
end
