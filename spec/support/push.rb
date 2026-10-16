# frozen_string_literal: true

module PushHelpers
  def push_response_error(klass, status)
    klass.new(Struct.new(:code, :body).new(status.to_s, ""), "push.example.com")
  end

  def stub_web_push
    allow(WebPush).to receive(:payload_send)
  end

  def pushed_messages
    WebPush.received_messages.map { |message| JSON.parse(message[:message]) }
  end
end

module WebPushRecorder
  def received_messages
    @received_messages ||= []
  end
end

WebPush.extend(WebPushRecorder)

RSpec.configure do |config|
  config.include PushHelpers

  config.before do
    WebPush.received_messages.clear
    allow(WebPush).to receive(:payload_send) { |**options| WebPush.received_messages << options }
  end
end
