# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GoodJob tracker lock order" do
  def waiting_for_connection_lock?(thread)
    thread.backtrace&.any? { |frame| frame.include?("ThreadMonitor#mon_enter") }
  end

  it "finishes an inline job while a request thread enqueues another from inside a transaction" do
    request_started = Queue.new
    original_destroy = GoodJob::Process.instance_method(:destroy)
    request = nil
    request_reached_lock = false

    allow_any_instance_of(GoodJob::Process).to receive(:destroy) do |record|
      if request.nil?
        request = Thread.new do
          ActiveRecord::Base.transaction(requires_new: true) do
            request_started << true
            Turbo::Streams::BroadcastStreamJob.perform_later("lock-order", content: "from the request")
          end
        end
        50.times do
          request_reached_lock = !request_started.empty? || waiting_for_connection_lock?(request)
          break if request_reached_lock
          sleep 0.1
        end
        sleep 0.2 unless request_started.empty?
      end
      original_destroy.bind_call(record)
    end

    test_thread = Thread.new { Turbo::Streams::BroadcastStreamJob.perform_later("lock-order", content: "from the test") }
    finished = test_thread.join(10)
    unless finished
      request.kill
      request.join(5)
      test_thread.join(5)
    end

    expect(request_reached_lock).to be(true), "the request thread never reached the connection lock"
    expect(finished).not_to be_nil, "the test thread deadlocked against the request thread"
    expect(request.join(10)).not_to be_nil
  end
end
