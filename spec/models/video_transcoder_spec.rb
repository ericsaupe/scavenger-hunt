# frozen_string_literal: true

require "rails_helper"

RSpec.describe VideoTranscoder do
  describe "#command" do
    it "asks ffmpeg for a faststart H.264 MP4 that fits 1920x1080 and plays anywhere" do
      command = described_class.new("/tmp/original.mov", "/tmp/playback.mp4").command

      expect(command).to eq([
        "nice", "-n", "19",
        Rails.root.join("spec/support/bin/ffmpeg").to_s, "-nostdin", "-y", "-loglevel", "error",
        "-protocol_whitelist", "file", "-format_whitelist", "mov,mp4,m4a,3gp,3g2,mj2,matroska,webm",
        "-threads", "1", "-i", "/tmp/original.mov",
        "-t", "61",
        "-vf", "scale=w='if(gt(a,1),min(1920,iw),min(1080,iw))':h='if(gt(a,1),min(1080,ih),min(1920,ih))':force_original_aspect_ratio=decrease:force_divisible_by=2,fps=fps='min(source_fps,60)'", "-threads", "1",
        "-c:v", "libx264", "-profile:v", "high", "-level", "4.2", "-pix_fmt", "yuv420p", "-preset", "veryfast", "-crf", "22",
        "-c:a", "aac", "-b:a", "128k",
        "-movflags", "+faststart",
        "/tmp/playback.mp4"
      ])
    end
  end

  describe ".duration" do
    let(:log) { Tempfile.new("ffprobe", Rails.root.join("tmp")) }

    around do |example|
      ENV["FAKE_FFPROBE_LOG"] = log.path
      example.run
    ensure
      ENV.delete("FAKE_FFPROBE_LOG")
      log.close!
    end

    it "probes the file with the same input restrictions as the conversion" do
      expect(described_class.duration("/tmp/original.mov")).to eq(5.0)

      log.rewind
      expect(log.read.chomp.split("\t")).to eq(["-protocol_whitelist", "file", "-format_whitelist", "mov,mp4,m4a,3gp,3g2,mj2,matroska,webm",
        "-print_format", "json", "-show_streams", "-show_format", "-v", "error", "/tmp/original.mov"])
    end

    it "is nil when the probe reports no length", ffprobe_duration: "none" do
      expect(described_class.duration("/tmp/original.mov")).to be_nil
    end
  end

  describe ".transcode" do
    it "kills ffmpeg when it runs past the time limit" do
      stub_const("VideoTranscoder::TIMEOUT", 1.second)
      ENV["FAKE_FFMPEG_SLEEP"] = "10"
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      expect { described_class.transcode("/tmp/original.mov", "/tmp/playback.mp4") }
        .to raise_error(VideoTranscoder::Error, "ffmpeg gave up after 1 second")
      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started).to be < 5
    ensure
      ENV.delete("FAKE_FFMPEG_SLEEP")
    end

    it "raises with ffmpeg's complaint when the conversion fails" do
      ENV["FAKE_FFMPEG_FAIL"] = "1"

      expect { described_class.transcode("/tmp/original.mov", "/tmp/playback.mp4") }
        .to raise_error(VideoTranscoder::Error, "ffmpeg failed (status 1): Conversion failed!")
    ensure
      ENV.delete("FAKE_FFMPEG_FAIL")
    end
  end
end
