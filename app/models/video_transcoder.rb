# frozen_string_literal: true

require "open3"

class VideoTranscoder
  class Error < StandardError; end

  MAX_WIDTH = 1280
  MAX_HEIGHT = 720
  SCALE = "scale=w='if(gt(a,1),min(#{MAX_WIDTH},iw),min(#{MAX_HEIGHT},iw))':" \
    "h='if(gt(a,1),min(#{MAX_HEIGHT},ih),min(#{MAX_WIDTH},ih))':" \
    "force_original_aspect_ratio=decrease:force_divisible_by=2"

  def self.transcode(input, output)
    new(input, output).transcode
  end

  attr_reader :input, :output

  def initialize(input, output)
    @input = input
    @output = output
  end

  def command
    [ActiveStorage::Previewer::VideoPreviewer.ffmpeg_path, "-nostdin", "-y", "-loglevel", "error",
      "-i", input,
      "-vf", SCALE,
      "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-pix_fmt", "yuv420p", "-preset", "veryfast", "-crf", "23",
      "-c:a", "aac", "-b:a", "128k",
      "-movflags", "+faststart",
      output]
  end

  def transcode
    _stdout, stderr, status = Open3.capture3(*command)
    raise Error, "ffmpeg failed (status #{status.exitstatus}): #{stderr.strip}" unless status.success?

    output
  end
end
