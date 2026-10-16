# frozen_string_literal: true

require "rails_helper"

RSpec.describe "GoodJob tracker lock order" do
  it "finishes an inline job while a request thread enqueues another from inside a transaction" do
    request_started = Queue.new
    original_destroy = GoodJob::Process.instance_method(:destroy)
    request = nil

    allow_any_instance_of(GoodJob::Process).to receive(:destroy) do |record|
      if request.nil?
        request = Thread.new do
          ActiveRecord::Base.transaction(requires_new: true) do
            request_started << true
            Turbo::Streams::BroadcastStreamJob.perform_later("lock-order", content: "from the request")
          end
        end
        request_started.pop(timeout: 1)
        sleep 0.2
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

    expect(finished).not_to be_nil, "the test thread deadlocked against the request thread"
    expect(request.join(10)).not_to be_nil
  end
end
