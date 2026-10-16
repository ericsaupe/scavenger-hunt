# frozen_string_literal: true

require "open3"

class VideoTranscoder
  class Error < StandardError; end

  MAX_WIDTH = 1280
  MAX_HEIGHT = 720
  TIMEOUT = 10.minutes
  INPUT_OPTIONS = ["-protocol_whitelist", "file", "-format_whitelist", "mov,mp4,m4a,3gp,3g2,mj2,matroska,webm"].freeze
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
      *INPUT_OPTIONS, "-i", input,
      "-t", Submission::MAX_VIDEO_SECONDS.to_s,
      "-vf", SCALE,
      "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-pix_fmt", "yuv420p", "-preset", "veryfast", "-crf", "23",
      "-c:a", "aac", "-b:a", "128k",
      "-movflags", "+faststart",
      output]
  end

  def transcode
    Open3.popen3(*command, pgroup: true) do |stdin, stdout, stderr, process|
      stdin.close
      drain = Thread.new { stdout.read }
      errors = Thread.new { stderr.read }

      finished = process.join(TIMEOUT)
      Process.kill("KILL", -process.pid) unless finished
      drain.join
      complaint = errors.value.strip

      raise Error, "ffmpeg gave up after #{TIMEOUT.inspect}" unless finished
      raise Error, "ffmpeg failed (status #{process.value.exitstatus}): #{complaint}" unless process.value.success?
    end

    output
  end
end
