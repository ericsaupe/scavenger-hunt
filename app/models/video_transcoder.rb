# frozen_string_literal: true

require "open3"

class VideoTranscoder
  class Error < StandardError; end

  MAX_WIDTH = 1920
  MAX_HEIGHT = 1080
  MAX_FPS = 60
  LEVEL = "4.2"
  CRF = "22"
  TIMEOUT = 10.minutes
  INPUT_OPTIONS = ["-protocol_whitelist", "file", "-format_whitelist", "mov,mp4,m4a,3gp,3g2,mj2,matroska,webm"].freeze
  SCALE = "scale=w='if(gt(a,1),min(#{MAX_WIDTH},iw),min(#{MAX_HEIGHT},iw))':" \
    "h='if(gt(a,1),min(#{MAX_HEIGHT},ih),min(#{MAX_WIDTH},ih))':" \
    "force_original_aspect_ratio=decrease:force_divisible_by=2"
  FILTERS = "#{SCALE},fps=fps='min(source_fps,#{MAX_FPS})'"

  def self.transcode(input, output)
    new(input, output).transcode
  end

  def self.ffmpeg_path
    ActiveStorage::Previewer::VideoPreviewer.ffmpeg_path
  end

  def self.ffprobe_path
    ActiveStorage.paths[:ffprobe] || "ffprobe"
  end

  def self.probe(path)
    output = run([ffprobe_path, *INPUT_OPTIONS, "-print_format", "json", "-show_streams", "-show_format", "-v", "error", path]).string
    JSON.parse(output)
  rescue Error, Errno::ENOENT, JSON::ParserError => error
    Rails.logger.info("Skipping video probe: #{error.message}")
    {}
  end

  def self.duration(path)
    probed = probe(path)
    stream = Array(probed["streams"]).find { |candidate| candidate["codec_type"] == "video" } || {}
    duration = stream["duration"] || probed.dig("format", "duration")
    Float(duration) if duration
  end

  def self.run(command, into: StringIO.new)
    Open3.popen3(*command, pgroup: true) do |stdin, stdout, stderr, process|
      stdin.close
      drain = Thread.new { IO.copy_stream(stdout, into) }
      errors = Thread.new { stderr.read }

      finished = process.join(TIMEOUT)
      kill(process.pid) unless finished
      drain.join
      complaint = errors.value.strip
      program = File.basename(command.first)

      raise Error, "#{program} gave up after #{TIMEOUT.inspect}" unless finished
      raise Error, "#{program} failed (status #{process.value.exitstatus}): #{complaint}" unless process.value.success?
    end

    into
  end

  def self.kill(pid)
    Process.kill("KILL", -pid)
  rescue Errno::ESRCH
    nil
  end

  attr_reader :input, :output

  def initialize(input, output)
    @input = input
    @output = output
  end

  def command
    [self.class.ffmpeg_path, "-nostdin", "-y", "-loglevel", "error",
      *INPUT_OPTIONS, "-i", input,
      "-t", Submission::MAX_VIDEO_SECONDS.to_s,
      "-vf", FILTERS,
      "-c:v", "libx264", "-profile:v", "high", "-level", LEVEL, "-pix_fmt", "yuv420p", "-preset", "veryfast", "-crf", CRF,
      "-c:a", "aac", "-b:a", "128k",
      "-movflags", "+faststart",
      output]
  end

  def transcode
    self.class.run(command, into: File::NULL.then { |null| File.open(null, "w") })
    output
  end
end
