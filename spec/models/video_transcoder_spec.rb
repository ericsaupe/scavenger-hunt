# frozen_string_literal: true

require "rails_helper"

RSpec.describe VideoTranscoder do
  describe "#command" do
    it "asks ffmpeg for a faststart H.264 MP4 that fits 1280x720 and plays anywhere" do
      command = described_class.new("/tmp/original.mov", "/tmp/playback.mp4").command

      expect(command).to eq([
        Rails.root.join("spec/support/bin/ffmpeg").to_s, "-nostdin", "-y", "-loglevel", "error",
        "-i", "/tmp/original.mov",
        "-vf", "scale=w='if(gt(a,1),min(1280,iw),min(720,iw))':h='if(gt(a,1),min(720,ih),min(1280,ih))':force_original_aspect_ratio=decrease:force_divisible_by=2",
        "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-pix_fmt", "yuv420p", "-preset", "veryfast", "-crf", "23",
        "-c:a", "aac", "-b:a", "128k",
        "-movflags", "+faststart",
        "/tmp/playback.mp4"
      ])
    end
  end

  describe ".transcode" do
    it "raises with ffmpeg's complaint when the conversion fails" do
      ENV["FAKE_FFMPEG_FAIL"] = "1"

      expect { described_class.transcode("/tmp/original.mov", "/tmp/playback.mp4") }
        .to raise_error(VideoTranscoder::Error, "ffmpeg failed (status 1): Conversion failed!")
    ensure
      ENV.delete("FAKE_FFMPEG_FAIL")
    end
  end
end
