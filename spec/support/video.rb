# frozen_string_literal: true

RSpec.configure do |config|
  config.around(:each, :ffprobe_duration) do |example|
    ENV["FAKE_FFPROBE_DURATION"] = example.metadata[:ffprobe_duration].to_s
    example.run
  ensure
    ENV.delete("FAKE_FFPROBE_DURATION")
  end
end
