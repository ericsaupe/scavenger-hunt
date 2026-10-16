# frozen_string_literal: true

class EnableVideoTranscoding < ActiveRecord::Migration[8.1]
  def up
    Flipper.enable(:video_transcoding)
  end

  def down
    Flipper.remove(:video_transcoding)
  end
end
